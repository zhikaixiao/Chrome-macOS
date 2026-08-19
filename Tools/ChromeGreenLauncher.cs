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

internal static class ChromeGreenLauncher
{
    private const string DefaultStartPage = "https://www.bing.com/";
    private const string BingSearchProviderGuid =
        "485bf7d3-0215-45af-87dc-538868000003";
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
            logPath = Path.Combine(rootPath, "Data", "ChromeGreenLauncher.log");

            string chromePath = Path.Combine(rootPath, "App", "Chrome-bin", "chrome.exe");
            string profilePath = Path.Combine(rootPath, "Data", "Profile");
            string[] extensionPaths =
            {
                Path.Combine(rootPath, "Extensions", "Violentmonkey"),
                Path.Combine(rootPath, "Extensions", "uBOLite"),
                Path.Combine(rootPath, "Extensions", "KissTranslator")
            };

            ValidatePackage(chromePath, extensionPaths);
            Directory.CreateDirectory(profilePath);
            Directory.CreateDirectory(Path.GetDirectoryName(logPath));

            bool createdNew;
            instanceMutex = new Mutex(true, BuildMutexName(rootPath), out createdNew);
            if (!createdNew)
            {
                StartAdditionalWindow(chromePath, profilePath, userArguments);
                return 0;
            }

            WriteLog("Starting Chrome Green.");
            EnsureBingDefaultSearch(profilePath);
            chromeProcess = StartControlledChrome(
                chromePath,
                profilePath,
                extensionPaths,
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
                catch
                {
                }
            }

            MessageBox.Show(
                "Chrome Green could not start.\r\n\r\n" +
                ex.Message +
                "\r\n\r\nDetails were written to:\r\n" +
                (logPath ?? "Data\\ChromeGreenLauncher.log"),
                "Chrome Green",
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

    private static void ValidatePackage(string chromePath, string[] extensionPaths)
    {
        if (!File.Exists(chromePath))
        {
            throw new FileNotFoundException("Chrome executable is missing.", chromePath);
        }

        foreach (string extensionPath in extensionPaths)
        {
            string manifestPath = Path.Combine(extensionPath, "manifest.json");
            if (!File.Exists(manifestPath))
            {
                throw new FileNotFoundException(
                    "A bundled extension is incomplete.",
                    manifestPath);
            }
        }
    }

    private static void EnsureBingDefaultSearch(string profilePath)
    {
        string preferencesPath = Path.Combine(
            profilePath,
            "Default",
            "Preferences");
        if (!File.Exists(preferencesPath))
        {
            WriteLog("Chrome preferences do not exist yet; Bing will be the startup page.");
            return;
        }

        string preferences = File.ReadAllText(
            preferencesPath,
            Encoding.UTF8);
        string provider =
            "\"default_search_provider\":{\"guid\":\"" +
            BingSearchProviderGuid +
            "\"}";
        string providerPattern =
            "\"default_search_provider\"\\s*:\\s*\\{[^{}]*\\}";
        string updated;

        if (Regex.IsMatch(preferences, providerPattern))
        {
            updated = new Regex(providerPattern).Replace(
                preferences,
                provider,
                1);
        }
        else
        {
            int rootObjectStart = preferences.IndexOf('{');
            if (rootObjectStart < 0)
            {
                throw new InvalidDataException(
                    "Chrome Preferences is not a valid JSON object.");
            }

            updated = preferences.Insert(
                rootObjectStart + 1,
                provider + ",");
        }

        if (!string.Equals(preferences, updated, StringComparison.Ordinal))
        {
            File.WriteAllText(
                preferencesPath,
                updated,
                new UTF8Encoding(false));
        }

        WriteLog("Default search engine set to Microsoft Bing.");
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
                throw new InvalidOperationException("The Chrome process did not start.");
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

                if (string.Equals(
                    Path.GetFileName(extensionPath),
                    "Violentmonkey",
                    StringComparison.OrdinalIgnoreCase))
                {
                    string extensionId = ExtractStringProperty(
                        response,
                        "id");
                    ConfigureViolentmonkeyAndCloseStartupPages(
                        chromeInput,
                        chromeOutput,
                        extensionId);
                }
            }

            string listResponse = Call(
                chromeInput,
                chromeOutput,
                "Extensions.getExtensions",
                "{}");
            EnsureSuccessfulResponse(listResponse, "Extensions.getExtensions");

            WriteLog("All bundled extensions are enabled.");
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
            throw new InvalidOperationException(
                "Chrome did not accept the additional window request.");
        }
    }

    private static List<string> BuildBaseArguments(string profilePath)
    {
        List<string> arguments = new List<string>();
        arguments.Add("--user-data-dir=" + profilePath);
        arguments.Add("--lang=zh-CN");
        arguments.Add("--no-first-run");
        arguments.Add("--no-default-browser-check");
        return arguments;
    }

    private static void AddUserArguments(
        List<string> arguments,
        string[] userArguments)
    {
        if (userArguments == null || userArguments.Length == 0)
        {
            arguments.Add(DefaultStartPage);
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
                throw new ArgumentException(
                    "This Chrome argument is reserved by the portable launcher: " +
                    argument);
            }

            arguments.Add(argument);
        }
    }

    private static string ExtractStringProperty(
        string json,
        string propertyName)
    {
        Match match = Regex.Match(
            json ?? string.Empty,
            "\\\"" + Regex.Escape(propertyName) +
            "\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"");
        return match.Success ? match.Groups[1].Value : null;
    }

    private static void ConfigureViolentmonkeyAndCloseStartupPages(
        Stream chromeInput,
        Stream chromeOutput,
        string extensionId)
    {
        if (string.IsNullOrWhiteSpace(extensionId))
        {
            WriteLog("Could not identify the Violentmonkey extension ID.");
            return;
        }

        string extensionUrlPrefix =
            "chrome-extension://" + extensionId + "/";

        // Configure the permission through Chrome's own extensions page in a
        // background target before Violentmonkey has time to show guidance.
        string settingsUrl =
            "chrome://extensions/?id=" + extensionId;
        string createResponse = Call(
            chromeInput,
            chromeOutput,
            "Target.createTarget",
            "{\"url\":\"" + EscapeJson(settingsUrl) +
            "\",\"background\":true}");
        string settingsTargetId = ExtractStringProperty(
            createResponse,
            "targetId");
        if (!string.IsNullOrEmpty(settingsTargetId))
        {
            EnableUserScriptsAccess(
                chromeInput,
                chromeOutput,
                settingsTargetId,
                extensionId);
            Call(
                chromeInput,
                chromeOutput,
                "Target.closeTarget",
                "{\"targetId\":\"" +
                EscapeJson(settingsTargetId) +
                "\"}");
        }
        else
        {
            WriteLog(
                "Could not create the background extension settings page: " +
                createResponse);
        }

        // The extension may create its welcome/options tab shortly after its
        // load request completes, so check a few times during startup.
        for (int attempt = 0; attempt < 10; attempt++)
        {
            if (attempt > 0)
            {
                Thread.Sleep(200);
            }

            string targetsResponse = Call(
                chromeInput,
                chromeOutput,
                "Target.getTargets",
                "{}");

            foreach (Match objectMatch in Regex.Matches(
                targetsResponse,
                "\\{[^{}]*\\}"))
            {
                string target = objectMatch.Value;
                string type = ExtractStringProperty(target, "type");
                string url = ExtractStringProperty(target, "url");
                string targetId = ExtractStringProperty(target, "targetId");

                if (!string.Equals(
                        type,
                        "page",
                        StringComparison.OrdinalIgnoreCase) ||
                    string.IsNullOrEmpty(url) ||
                    string.IsNullOrEmpty(targetId))
                {
                    continue;
                }

                bool isViolentmonkeyPage = url.StartsWith(
                    extensionUrlPrefix,
                    StringComparison.OrdinalIgnoreCase);
                bool isViolentmonkeyDetailsPage =
                    url.StartsWith(
                        "chrome://extensions/",
                        StringComparison.OrdinalIgnoreCase) &&
                    url.IndexOf(
                        extensionId,
                        StringComparison.OrdinalIgnoreCase) >= 0;

                if (!isViolentmonkeyPage && !isViolentmonkeyDetailsPage)
                {
                    continue;
                }

                if (string.Equals(
                    targetId,
                    settingsTargetId,
                    StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                if (isViolentmonkeyDetailsPage)
                {
                    EnableUserScriptsAccess(
                        chromeInput,
                        chromeOutput,
                        targetId,
                        extensionId);
                }

                string closeResponse = Call(
                    chromeInput,
                    chromeOutput,
                    "Target.closeTarget",
                    "{\"targetId\":\"" +
                    EscapeJson(targetId) +
                    "\"}");

                if (!Regex.IsMatch(
                    closeResponse,
                    "\\\"error\\\"\\s*:"))
                {
                    WriteLog(
                        "Closed Violentmonkey startup page: " + url);
                }
            }
        }
    }

    private static void EnableUserScriptsAccess(
        Stream chromeInput,
        Stream chromeOutput,
        string targetId,
        string extensionId)
    {
        string attachResponse = null;
        string sessionId = null;
        for (int attempt = 0; attempt < 10; attempt++)
        {
            if (attempt > 0)
            {
                Thread.Sleep(100);
            }

            attachResponse = Call(
                chromeInput,
                chromeOutput,
                "Target.attachToTarget",
                "{\"targetId\":\"" + EscapeJson(targetId) +
                "\",\"flatten\":true}");
            sessionId = ExtractStringProperty(
                attachResponse,
                "sessionId");
            if (!string.IsNullOrEmpty(sessionId))
            {
                break;
            }
        }

        if (string.IsNullOrEmpty(sessionId))
        {
            WriteLog(
                "Could not attach to the Violentmonkey details page: " +
                attachResponse);
            return;
        }

        // Violentmonkey uses an alert to explain the required switch. Dismiss
        // it first because a JavaScript dialog pauses the page's renderer.
        Call(
            chromeInput,
            chromeOutput,
            "Page.handleJavaScriptDialog",
            "{\"accept\":true}",
            sessionId);

        string id = EscapeJavaScriptString(extensionId);
        string expression =
            "new Promise(function(resolve){" +
            "chrome.developerPrivate.getExtensionInfo('" + id +
            "',function(info){" +
            "if(chrome.runtime.lastError){resolve(false);return;}" +
            "if(info&&info.userScriptsAccess&&" +
            "info.userScriptsAccess.isActive){resolve(true);return;}" +
            "chrome.developerPrivate.updateExtensionConfiguration({" +
            "extensionId:'" + id + "',userScriptsAccess:true}," +
            "function(){" +
            "if(chrome.runtime.lastError){resolve(false);return;}" +
            "chrome.developerPrivate.getExtensionInfo('" + id +
            "',function(updated){resolve(!!(updated&&" +
            "updated.userScriptsAccess&&" +
            "updated.userScriptsAccess.isActive));});" +
            "});" +
            "});" +
            "})";

        string evaluateResponse = Call(
            chromeInput,
            chromeOutput,
            "Runtime.evaluate",
            "{\"expression\":\"" + EscapeJson(expression) +
            "\",\"awaitPromise\":true,\"returnByValue\":true}",
            sessionId);

        if (Regex.IsMatch(
            evaluateResponse,
            "\\\"value\\\"\\s*:\\s*true"))
        {
            WriteLog("Enabled Allow User Scripts for Violentmonkey.");
        }
        else
        {
            WriteLog(
                "Could not enable Allow User Scripts automatically: " +
                evaluateResponse);
        }
    }

    private static string EscapeJavaScriptString(string value)
    {
        return (value ?? string.Empty)
            .Replace("\\", "\\\\")
            .Replace("'", "\\'")
            .Replace("\r", "\\r")
            .Replace("\n", "\\n");
    }

    private static string Call(
        Stream chromeInput,
        Stream chromeOutput,
        string method,
        string parameters)
    {
        return Call(
            chromeInput,
            chromeOutput,
            method,
            parameters,
            null);
    }

    private static string Call(
        Stream chromeInput,
        Stream chromeOutput,
        string method,
        string parameters,
        string sessionId)
    {
        int messageId = nextMessageId++;
        string request =
            "{\"id\":" +
            messageId +
            ",\"method\":\"" +
            EscapeJson(method) +
            "\",\"params\":" +
            parameters +
            (string.IsNullOrEmpty(sessionId)
                ? string.Empty
                : ",\"sessionId\":\"" +
                  EscapeJson(sessionId) +
                  "\"") +
            "}\0";
        byte[] requestBytes = Encoding.UTF8.GetBytes(request);
        chromeInput.Write(requestBytes, 0, requestBytes.Length);
        chromeInput.Flush();

        while (true)
        {
            string response = ReadMessage(chromeOutput);
            if (response == null)
            {
                throw new EndOfStreamException(
                    "Chrome closed the extension loading channel.");
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
                operation + " failed. Chrome response: " + response);
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
            StringBuilder value = new StringBuilder("Local\\ChromeGreen_");
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
        catch
        {
        }
    }
}
