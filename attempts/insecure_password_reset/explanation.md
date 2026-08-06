## Vulnerability: Insecure Password Reset (Token Leakage)
### OWASP Category: A07:2021 - Identification and Authentication Failures
### Description
When trying to recover a password, the user is prompted to put an email. Once that request goes through a reset token is generated. Instead of sending it safely via email, the token is shown in the url.

before and after:
```
http://localhost:4942/reset-password
http://localhost:4942/reset-password?email=test@tech.42&token=9c567ae1f6aa261ac0f7adfc03a0b3b6
```
### Impact
This allows for a complete Account Takeover by just knowing a valid email address. The attacker will request a password reset, and use the token provided in the URL to set a new password.

### Solution Idea
1. The reset token must never be included in the HTTP response (neither in the URL, headers, nor the body) sent back to the client requesting the reset.
2. The application must send the token exclusively to the registered email address associated with the account.