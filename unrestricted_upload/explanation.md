## Unrestricted File Upload

### How it works
The application provides an avatar upload feature at `/profile/me/settings`. However, the backend completely lacks file validation (e.g., verifying extensions or MIME types) because the upload whitelist was removed by the developers. 

By uploading a file with a potentially dangerous extension (such as `.php`, `.sh`, or `.html`) instead of a standard image format, the server accepts and processes the file without raising an error. The application detects this unrestricted upload attempt and returns a success banner containing the flag in the UI and the redirect URL.

### Impact
Unrestricted file uploads are critical vulnerabilities. If an attacker uploads a malicious executable file (like a PHP web shell) and the server stores it within the web root without preventing execution, the attacker gains Remote Code Execution (RCE). This allows them to run arbitrary commands on the server, leading to a full system compromise.

### How it could have been avoided
1. **Strict Whitelisting:** Implement a strict whitelist of allowed file extensions (e.g., only `.jpg`, `.png`, `.gif`).
2. **Content Validation:** Verify the file's "Magic Bytes" (file signature) and MIME type to ensure the content matches the extension.
3. **Safe Storage:** Store uploaded files outside of the web root or on a separate storage server (like an S3 bucket).
4. **Prevent Execution:** Configure the web server directory where files are stored to deny the execution of scripts (e.g., disabling PHP execution in the `uploads` folder).