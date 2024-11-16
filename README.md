# Zscaler - certificate installation on Mac OS

Tools to work with Zscaler certificates on Mac OS

## Background

I recently set up a new Mac in a work context, where traffic is tunneled through a Zscaler proxy.
This worked without issue for web browsing, email, Teams etc.
It would be fair to say that there was "some assembly required" for working with other tools, and I particularly ran into an issue with Azure CLI.

### Homebrew installation

Install homebrew from (brew.sh)[https://brew.sh/] by running

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

which had installed the binary into `/opt/homebrew/bin/brew`

### Azure CLI installation via homebrew

Install Azure CLI [via homebrew](https://formulae.brew.sh/formula/azure-cli#default) by running

```shell
brew install azure-cli
```

which had installed the binary into `/opt/homebrew/bin/az`

## Reference

From Sergio Pereira:

- [zscaler-cert-app-store](https://github.com/sergitopereira/zscaler-cert-app-store) which uses Python
- [certuploader](https://github.com/sergitopereira/certuploader) which uses a single compiled Go binary, and also contains two certificates
  - [ZscalerRootCertificate.crt](https://github.com/sergitopereira/certuploader/blob/main/cert/ZscalerRootCertificate.crt)
  - [certBundle.pem](https://github.com/sergitopereira/certuploader/blob/main/cert/certBundle.pem)

From Azure:

- [Azure CLI behind a proxy](https://learn.microsoft.com/en-gb/cli/azure/use-azure-cli-successfully-troubleshooting#work-behind-a-proxy)
  This documentation assumes a path at

```
/usr/local/Cellar/azure-cli/<cliversion>/libexec/lib/python<version>/site-packages/certifi/cacert.pem
```

- this was not the case when brew was installed under `/opt`, hence the need for this array

```shell
HOMEBREW_PATHS=("/opt/homebrew/Cellar/azure-cli" "/usr/local/Cellar/azure-cli")
```

From Zscaler:

- [Adding Custom Certificate to an Application-Specific Trust Store](https://help.zscaler.com/zia/adding-custom-certificate-application-specific-trust-store)
- [Choosing the CA Certificate for SSL Inspection](https://help.zscaler.com/zia/choosing-ca-certificate-ssl-inspection)
- [Zscaler certificate tips](https://community.zscaler.com/zenith/s/question/0D54u00009evmlCCAQ/zscaler-certificate-tips)

## Design goals

- A bash script which I understand, and which throws no [shellcheck](https://github.com/koalaman/shellcheck) errors or warnings
- Idempotence - re-run the script with confidence
- A dry-run flag to know of changes ahead of time

## A process which worked for me

```shell
mkdir -p $HOME/.zscalerCerts
```

Download the certificates from (internal) documentation into

- $HOME/.zscalerCerts/ZscalerRootCertificate.crt
- $HOME/.zscalerCerts/zscalerCAbundle.pem

> Note. At your own risk, you may wish to download the two certificates from [Sergio Pereira's repo](https://github.com/sergitopereira/certuploader/tree/main/cert) into `$HOME/.zscalerCerts`, and ensure the names are correct (rename `certBundle.pem` as `zscalerCAbundle.pem`)

```shell
./zscaler-mac.sh --azure-cli --dry-run
```

Review the output, and re-run without the `--dry-run` flag

```shell
./zscaler-mac.sh --azure-cli
```

## Working with `.zshrc`

You can choose to run the script above with the `--profile` flag

```shell
./zscaler-mac.sh --azure-cli --profile
```

Or if you need to have a profile file which works on machines which may not have Zscaler certs, you may wish to use this block

```shell
if [ -d "$HOME/.zscalerCerts" ]; then
  export AWS_CA_BUNDLE="$HOME/.zscalerCerts/zscalerCAbundle.pem"
  export CURL_CA_BUNDLE="$HOME/.zscalerCerts/zscalerCAbundle.pem"
  export GIT_SSL_CAPATH="$HOME/.zscalerCerts/zscalerCAbundle.pem"
  export NODE_EXTRA_CA_CERTS="$HOME/.zscalerCerts/zscalerCAbundle.pem"
  export REQUESTS_CA_BUNDLE="$HOME/.zscalerCerts/azure-cacert.pem"
  export SSL_CERT_FILE="$HOME/.zscalerCerts/zscalerCAbundle.pem"
fi
```
