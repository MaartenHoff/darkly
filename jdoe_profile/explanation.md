## Weak Password & Missing Brute-Force Protection

### How it works
jdoe's email (`jdoe@student.42.tech`) is found via his forum profile. Forum posts hint his password is in `rockyou.txt` and near the top. The login page (`/login`) has no rate limiting, so a simple dictionary attack finds the password within seconds: `abc123`.

### Impact
Attackers can run automated dictionary or credential stuffing attacks without interruption. Combined with weak user credentials, this leads to immediate Account Takeovers (ATO) and unauthorized access to the platform.

### How it could have been avoided
1. **Rate Limiting & Account Lockout:** The server must limit login attempts per IP address/user account and temporarily lock the account after a threshold of failed attempts (e.g., 5 attempts).
2. **Password Policy:** The application should enforce password complexity rules and proactively reject passwords that are part of known data breaches (like `rockyou.txt`).
