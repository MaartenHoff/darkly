## goal: sql injection
### through plain text field of "forgot password"

the theory is that the sql command internally is :
```bash 
SELECT * FROM users WHERE email = '$email'
```
our input would be exchanged with '$email'. To test if this approach could work I will start with a simple ' as input. So at their end:
```bash 
SELECT * FROM users WHERE email = '''
```
If their code is safe it would search for an email called '. And most likly output email not found. If not, the program would fail and we would know that we have a good chance to breach with SQL injection.

So before:
```
http://localhost:4942/reset-password
```
after:
```
http://localhost:4942/reset-password?email=%27&token=3590cb8af0bbb9e78c343b52b93773c9
```
### interesting
the website did not break - but the outcome enables another entry

in the url we see that the token to reset the password is just given to us. Great! That meeans that we just need an email, then change the password ourself and therefore gain excess to that user... simple.


sql injection did not work. I will keep this md once we find a SQL injection option.