# mbentley/open-webui

docker image for Open WebUI,  direct mirrors of the `ghcr.io/open-webui/open-webui` images

## Image Tags

### `mbentley/open-webui`

* Daily updates:
    * `0.3`, `0.2`, `0.1`
    * `0`

I've found that the Open WebUI images published to ghcr.io only have specific tags (e.g. - there are no `major.minor` tags) which makes it a pain to stay up to date on the latest bugfix versions.  [These scripts](./) will run daily to just create manifest tags for the `linux/amd64` images by querying for the latest tag from GitHub, parsing it, and writing manifests with the `major.minor` version only.

This allows for using the `major.minor` versions so that you'll always have the latest bugfix versions, such as:

* `mbentley/open-webui:0.3` is a manifest pointing to `ghcr.io/open-webui/open-webui:v0.3.5`

These manifests always use the same image digest as the newest bugfix versions available for each.
