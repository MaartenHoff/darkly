## Insecure Direct Object Reference (IDOR) / Broken Access Control

### How it works
If you navigate to the forum, find the pinned post by `wil` ("Scheduled maintenance..."), and click on `View profile`, you are directed to:
`http://localhost:4942/profile/k1asdfeditojrb4`

The flag is displayed right there under "Private note". The vulnerability exists because the backend blindly serves the data based on the user ID in the URL, without checking if the current visitor is actually authorized to see private fields.

### Impact
Any unauthorized user or guest can view sensitive, private data belonging to other users simply by knowing or guessing their profile URL.

### How it could have been avoided
The backend needs to implement strict access control. Before sending the profile data, the server must check the session token to verify if the requester is either the owner of the profile or an administrator.