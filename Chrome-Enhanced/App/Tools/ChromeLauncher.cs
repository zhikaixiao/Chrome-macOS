using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

internal static class ChromePortableLauncher
{
    private static string rootPath;
    private static string logPath;
    private static int nextMessageId = 1;

    [STAThread]
    private static int Main(string[] userArguments)
    {
        Process chromeProcess = null;
        Mutex instanceMutex = null;

        try
        {
            rootPath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            
            // 如果 Launcher 在 App\ 目录下，rootPath 取上一级
            if (File.Exists(Path.Combine(rootPath, "App", "Chrome-bin", "chrome.exe")))
            {
                // rootPath is workspace root
            }
            else if (File.Exists(Path.Combine(rootPath, "Chrome-bin", "chrome.exe")))
            {
                rootPath = Path.GetDirectoryName(rootPath);
            }

            string appDir = Path.Combine(rootPath, "App");
            string chromePath = Path.Combine(appDir, "Chrome-bin", "chrome.exe");
            string profilePath = Path.Combine(rootPath, "Data", "UserData");
            string extensionsBase = Path.Combine(appDir, "Extensions");
            logPath = Path.Combine(rootPath, "Data", "Launcher.log");

            // 自动检索 App\Extensions 目录下的所有有效扩展
            List<string> extensionList = new List<string>();
            if (Directory.Exists(extensionsBase))
            {
                foreach (string subDir in Directory.GetDirectories(extensionsBase))
                {
                    if (File.Exists(Path.Combine(subDir, "manifest.json")))
                    {
                        extensionList.Add(subDir);
                    }
                }
            }

            if (!File.Exists(chromePath))
            {
                MessageBox.Show(
                    "未找到 Google Chrome 内核，请先运行【一键安装配置.bat】进行初始化安装。",
                    "Google Chrome 便携版",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
                return 1;
            }

            Directory.CreateDirectory(profilePath);

            bool createdNew;
            instanceMutex = new Mutex(true, BuildMutexName(rootPath), out createdNew);
            if (!createdNew)
            {
                StartAdditionalWindow(chromePath, profilePath, userArguments);
                return 0;
            }

            WriteLog("Starting Google Chrome Portable with extensions.");
            chromeProcess = StartControlledChrome(
                chromePath,
                profilePath,
                extensionList.ToArray(),
                userArguments);
            chromeProcess.WaitForExit();
            WriteLog("Chrome exited.");
            return 0;
        }
        catch (Exception ex)
        {
            WriteLog("ERROR: " + ex);
            if (chromeProcess != null)
            {
                try
                {
                    if (!chromeProcess.HasExited)
                    {
                        chromeProcess.Kill();
                    }
                }
                catch {}
            }

            MessageBox.Show(
                "Google Chrome 便携版启动失败。\r\n\r\n" + ex.Message,
                "Google Chrome 便携版",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }
        finally
        {
            if (instanceMutex != null)
            {
                instanceMutex.Dispose();
            }
        }
    }

    private static Process StartControlledChrome(
        string chromePath,
        string profilePath,
        string[] extensionPaths,
        string[] userArguments)
    {
        using (AnonymousPipeServerStream chromeInput =
            new AnonymousPipeServerStream(
                PipeDirection.Out,
                HandleInheritability.Inheritable))
        using (AnonymousPipeServerStream chromeOutput =
            new AnonymousPipeServerStream(
                PipeDirection.In,
                HandleInheritability.Inheritable))
        {
            string inputHandle = chromeInput.GetClientHandleAsString();
            string outputHandle = chromeOutput.GetClientHandleAsString();

            List<string> arguments = BuildBaseArguments(profilePath);
            arguments.Add("--enable-unsafe-extension-debugging");
            arguments.Add("--remote-debugging-pipe");
            arguments.Add(
                "--remote-debugging-io-pipes=" +
                inputHandle +
                "," +
                outputHandle);
            AddUserArguments(arguments, userArguments);

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = chromePath;
            startInfo.Arguments = JoinArguments(arguments);
            startInfo.WorkingDirectory = Path.GetDirectoryName(chromePath);
            startInfo.UseShellExecute = false;

            Process process = Process.Start(startInfo);
            if (process == null)
            {
                throw new InvalidOperationException("Chrome 进程未能成功启动。");
            }

            chromeInput.DisposeLocalCopyOfClientHandle();
            chromeOutput.DisposeLocalCopyOfClientHandle();

            string versionResponse = Call(
                chromeInput,
                chromeOutput,
                "Browser.getVersion",
                "{}");
            EnsureSuccessfulResponse(versionResponse, "Browser.getVersion");

            foreach (string extensionPath in extensionPaths)
            {
                string parameters =
                    "{\"path\":\"" + EscapeJson(extensionPath) + "\"}";
                string response = Call(
                    chromeInput,
                    chromeOutput,
                    "Extensions.loadUnpacked",
                    parameters);
                EnsureSuccessfulResponse(
                    response,
                    "Extensions.loadUnpacked: " +
                    Path.GetFileName(extensionPath));
                WriteLog(
                    "Enabled extension: " +
                    Path.GetFileName(extensionPath));
            }

            WriteLog("All bundled extensions are successfully enabled via CDP.");
            process.EnableRaisingEvents = true;
            process.WaitForExit();
            return process;
        }
    }

    private static void StartAdditionalWindow(
        string chromePath,
        string profilePath,
        string[] userArguments)
    {
        List<string> arguments = BuildBaseArguments(profilePath);
        AddUserArguments(arguments, userArguments);

        ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.FileName = chromePath;
        startInfo.Arguments = JoinArguments(arguments);
        startInfo.WorkingDirectory = Path.GetDirectoryName(chromePath);
        startInfo.UseShellExecute = true;

        Process process = Process.Start(startInfo);
        if (process == null)
        {
            throw new InvalidOperationException("无法打开 Chrome 新窗口。");
        }
    }

    private static List<string> BuildBaseArguments(string profilePath)
    {
        List<string> arguments = new List<string>();
        arguments.Add("--user-data-dir=" + profilePath);
        arguments.Add("--lang=zh-CN");
        arguments.Add("--no-first-run");
        arguments.Add("--disable-fre");
        arguments.Add("--no-default-browser-check");
        arguments.Add("--disable-sync");
        arguments.Add("--disable-signin-promo");
        return arguments;
    }

    private static void AddUserArguments(
        List<string> arguments,
        string[] userArguments)
    {
        if (userArguments == null || userArguments.Length == 0)
        {
            arguments.Add("https://www.bing.com");
            return;
        }

        foreach (string argument in userArguments)
        {
            if (string.IsNullOrWhiteSpace(argument))
            {
                continue;
            }

            string lower = argument.ToLowerInvariant();
            if (lower.StartsWith("--user-data-dir") ||
                lower.StartsWith("--remote-debugging") ||
                lower == "--enable-unsafe-extension-debugging")
            {
                continue;
            }

            arguments.Add(argument);
        }
    }

    private static string Call(
        Stream chromeInput,
        Stream chromeOutput,
        string method,
        string parameters)
    {
        int messageId = nextMessageId++;
        string request =
            "{\"id\":" +
            messageId +
            ",\"method\":\"" +
            EscapeJson(method) +
            "\",\"params\":" +
            parameters +
            "}\0";
        byte[] requestBytes = Encoding.UTF8.GetBytes(request);
        chromeInput.Write(requestBytes, 0, requestBytes.Length);
        chromeInput.Flush();

        while (true)
        {
            string response = ReadMessage(chromeOutput);
            if (response == null)
            {
                throw new EndOfStreamException("Chrome CDP 通道已断开。");
            }

            Match idMatch = Regex.Match(
                response,
                "\"id\"\\s*:\\s*([0-9]+)");
            if (idMatch.Success &&
                idMatch.Groups[1].Value ==
                messageId.ToString())
            {
                return response;
            }
        }
    }

    private static string ReadMessage(Stream stream)
    {
        MemoryStream message = new MemoryStream();
        while (true)
        {
            int value = stream.ReadByte();
            if (value < 0)
            {
                return message.Length == 0
                    ? null
                    : Encoding.UTF8.GetString(message.ToArray());
            }

            if (value == 0)
            {
                return Encoding.UTF8.GetString(message.ToArray());
            }

            message.WriteByte((byte)value);
        }
    }

    private static void EnsureSuccessfulResponse(
        string response,
        string operation)
    {
        if (Regex.IsMatch(response, "\"error\"\\s*:"))
        {
            throw new InvalidOperationException(
                operation + " 失败。Chrome 响应: " + response);
        }
    }

    private static string JoinArguments(IEnumerable<string> arguments)
    {
        StringBuilder result = new StringBuilder();
        foreach (string argument in arguments)
        {
            if (result.Length > 0)
            {
                result.Append(' ');
            }

            result.Append(QuoteWindowsArgument(argument));
        }

        return result.ToString();
    }

    private static string QuoteWindowsArgument(string argument)
    {
        if (argument.Length > 0 &&
            argument.IndexOfAny(new[] { ' ', '\t', '\n', '\v', '"' }) < 0)
        {
            return argument;
        }

        StringBuilder quoted = new StringBuilder();
        quoted.Append('"');
        int backslashes = 0;

        foreach (char character in argument)
        {
            if (character == '\\')
            {
                backslashes++;
                continue;
            }

            if (character == '"')
            {
                quoted.Append('\\', backslashes * 2 + 1);
                quoted.Append('"');
                backslashes = 0;
                continue;
            }

            quoted.Append('\\', backslashes);
            backslashes = 0;
            quoted.Append(character);
        }

        quoted.Append('\\', backslashes * 2);
        quoted.Append('"');
        return quoted.ToString();
    }

    private static string EscapeJson(string value)
    {
        StringBuilder escaped = new StringBuilder();
        foreach (char character in value)
        {
            switch (character)
            {
                case '\\':
                    escaped.Append("\\\\");
                    break;
                case '"':
                    escaped.Append("\\\"");
                    break;
                case '\r':
                    escaped.Append("\\r");
                    break;
                case '\n':
                    escaped.Append("\\n");
                    break;
                case '\t':
                    escaped.Append("\\t");
                    break;
                default:
                    if (character < 32)
                    {
                        escaped.Append("\\u");
                        escaped.Append(((int)character).ToString("x4"));
                    }
                    else
                    {
                        escaped.Append(character);
                    }
                    break;
            }
        }

        return escaped.ToString();
    }

    private static string BuildMutexName(string path)
    {
        byte[] pathBytes = Encoding.UTF8.GetBytes(
            Path.GetFullPath(path).ToLowerInvariant());
        using (SHA256 sha256 = SHA256.Create())
        {
            byte[] hash = sha256.ComputeHash(pathBytes);
            StringBuilder value = new StringBuilder("Local\\ChromePortable_");
            for (int index = 0; index < 12; index++)
            {
                value.Append(hash[index].ToString("x2"));
            }

            return value.ToString();
        }
    }

    private static void WriteLog(string message)
    {
        try
        {
            if (string.IsNullOrEmpty(logPath))
            {
                return;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(logPath));
            File.AppendAllText(
                logPath,
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") +
                " " +
                message +
                Environment.NewLine,
                new UTF8Encoding(false));
        }
        catch {}
    }
}
