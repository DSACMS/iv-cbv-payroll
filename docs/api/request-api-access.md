# Requesting Access To Emmy API

## Connecting to Emmy API Sandbox

1) Reach out to [emmy@cms.hhs.gov](mailto:emmy@cms.hhs.gov), requesting a sandbox credential.

2) A client id and client secret will be delivered to you via encrypted channels, such as a Box share. 

3) Use that client ID and client secret to obtain a JWT for access to the sandbox API. Example as cURL:  

```
Turn on wrapCopy as textexport CLIENT_ID = "USER" export SECRET_ID = "SECRET" curl -X POST "https://emmy-sandbox.auth.us-east-1.amazoncognito.com/oauth2/token" \   -H "Content-Type: application/x-www-form-urlencoded" \  -u "$CLIENT_ID:$SECRET_ID" \   -d "grant_type=client_credentials" \   -d "scope=default-m2m-resource-server-uvagy1/read"
```

4) this will return an `access_token`. Also keep in mind the `expires_in` → the tokens only last for 3600 seconds. Use that access token to make requests using the [api spec](https://cmsgov.github.io/emmy-api/api-spec/).

## Connecting to Emmy API Production

1) Reach out to [emmy@cms.hhs.gov](mailto:emmy@cms.hhs.gov), requesting a production credential. Make sure that all agreements are signed at this point.

2) A client id and client secret will be delivered to you via encrypted channels, such as a Box share. 

3) Use that client ID and client secret to obtain a JWT for access to the production API. Example as cURL:  

```
Turn on wrapCopy as textexport CLIENT_ID = "USER" export SECRET_ID = "SECRET" curl -X POST "https://emmy-prod.auth.us-east-1.amazoncognito.com/oauth2/token" \   -H "Content-Type: application/x-www-form-urlencoded" \  -u "$CLIENT_ID:$SECRET_ID" \   -d "grant_type=client_credentials" \   -d "scope=default-m2m-resource-server-uvagy1/read"
```

4) this will return an `access_token`. Also keep in mind the `expires_in` → the tokens only last for 3600 seconds. Use that access token to make requests using the [api spec](https://cmsgov.github.io/emmy-api/api-spec/).