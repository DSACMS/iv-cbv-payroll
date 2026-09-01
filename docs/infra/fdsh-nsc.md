# Local FDSH NSC testing

Emmy’s FDSH NSC client uses mutual TLS to connect to the CMS Federal Data Hub
and then calls the National Student Clearinghouse service through the Hub.

The Hub only accepts traffic from allowlisted IP addresses. Emmy’s deployed
development and test environments use allowlisted network egress. A developer’s
laptop does not, so local development requires an SSH tunnel through the
allowlisted EC2 instance.

## Retrieve the local credentials

You need AWS CLI access, the AWS Session Manager plugin, and access to the
`/fdsh/mesh/impl/credentials` Secrets Manager secret. Retrieve the secret and
write its certificate and private key to local files:

```bash
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id /fdsh/mesh/impl/credentials \
  --query SecretString \
  --output text)

echo "$SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['cert'])" > client.crt
echo "$SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['certKey'])" > client.key

export HUB_CLIENT_ID=$(echo "$SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientKey'])")
export HUB_CLIENT_SECRET=$(echo "$SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientSecret'])")

chmod 600 client.key
unset SECRET
```

Do not commit or share `client.crt`, `client.key`, OAuth credentials, or access
tokens.

## Configure SSH over AWS SSM

Add this block to `~/.ssh/config`:

```text
Host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --profile nonprod --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
    User ec2-user
```

Open the tunnel using the current allowlisted instance ID supplied by the
team:

```bash
ssh -L 8443:impl.hub.cms.gov:443 -N -f <INSTANCE_ID>
```

The local `.env.local` configuration should use:

```bash
HUB_API_URL=https://impl.hub.cms.gov:8443
HUB_TOKEN_URL=https://impl.hub.cms.gov:8443/auth/oauth/v2/token
HUB_EDUCATION_ENROLLMENT_URL=mesh/imp1/NationalStudentClearinghouseService
HUB_CLIENT_CERT_PATH=/path/to/client.crt
HUB_CLIENT_KEY_PATH=/path/to/client.key
HUB_RESOLVE=impl.hub.cms.gov:8443:127.0.0.1
```

`HUB_RESOLVE` is honored only by the development Rails environment. It keeps
the Hub hostname for TLS/SNI while directing the TCP connection to the local
tunnel. Deployed environments connect directly to the Hub and must not set
`HUB_RESOLVE`.

Close the tunnel when finished:

```bash
pkill -f "L 8443:impl.hub.cms.gov"
```

If the TLS handshake fails, re-pull the certificate and key and verify that
they are a matching pair. If the request hangs, verify that the tunnel is
running. If the Hub reports `invalid_client`, re-pull the OAuth credentials.
