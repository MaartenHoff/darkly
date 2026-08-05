

## Vulnerability: Weak Password & Missing Brute-Force Protection
### OWASP Category: A07 - Identification and Authentication Failures

### How it works
first step getting jdoe's email address: through forums then a comment from john doe -> view profile (`http://localhost:4942/profile/z4p1cnx47mfy50f`) 
-> email address: `jdoe@student.42.tech`

through those forums we also learn that his password is most likly in the rockyou.txt. Furthermore it most likly is close to the top (`http://localhost:4942/forum/6viy7xi64gxpan3`).

Lastly we go onto login page (`http://localhost:4942/login`) and loop through the passwords in rockyou.txt with jdoes email address.

Since the password is almost at the top, brute forcing it works well: password: `abc123`


### Impact
Attackers can run automated dictionary or credential stuffing attacks without interruption. Combined with weak user credentials, this leads to immediate Account Takeovers (ATO) and unauthorized access to the platform.

### How it could have been avoided
1. **Rate Limiting & Account Lockout:** The server must limit the amount of login attempts per IP address/user account and temporarily lock the account after a threshold of failed attempts (e.g., 5 attempts).
2. **Password Policy:** The application should enforce password complexity rules and proactively reject passwords that are part of known data breaches (like `rockyou.txt`).