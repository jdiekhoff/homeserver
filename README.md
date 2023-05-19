# homeserver
Repo for configuration of home server

## Creating certificates

[Self signed certificates with openssl](https://alexanderzeitler.com/articles/Fixing-Chrome-missing_subjectAltName-selfsigned-cert-openssl/)

[Comprehensive self signed RootCA](https://jamielinux.com/docs/openssl-certificate-authority/introduction.html)

### Installing certificates

| Platform | Notes |
| -------- | ----- |
| iOS | [Apple Forum](https://discussions.apple.com/thread/251795291) |
| Android | |
| Mac | |
| Windows | |
| Linux | [Stackoverflow](https://superuser.com/a/719047/197707) |
| Heimdall | [Github](https://github.com/linuxserver/Heimdall#self-signed-certificates-and-local-cas) |

## Traefik custom JSON

To help with using Traefik with other HTTP services not in docker, I've updated the dynamic file provider to read a JSON list instead of repeating myself in YAML. You must set a variable in your .env file as `JSON_SERVICES` that is an escaped single line JSON string. Is this unnecessary and overcomplicated? Yes, but I wanted to test out templating in dynamic config with Traefik.

**Environment variable in .env file**

`JSON_SERVICES="{\"services\":[{\"name\":\"octoprint\",\"host\":\"http://YourLocalHostNameOrIpAddress:80\",\"ssl\":true},{\"name\":\"pi-hole\",\"host\":\"http://YourLocalHostNameOrIpAddress:8080\",\"ssl\":false}]}"`

**Pretty JSON for reference**
```json
{
  "services": [
    {
      "name": "octoprint",
      "host": "http://YourLocalHostNameOrIpAddress:80",
      "ssl": true
    },
    {
      "name": "pi-hole",
      "host": "http://YourLocalHostNameOrIpAddress:8080",
      "ssl": false
    }
  ]
}
```