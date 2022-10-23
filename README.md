
# libtrackerboy gh-pages

This branch is used for github pages. 11ty and Sass is used to build the web
site. The site will just display a basic summary of the project, as well as
release information and to host the documentation.

## Testing locally
 1. Install npm
 1. `npm install`
 1. `npm start`
 1. Test the site via [http://localhost:8080/libtrackerboy/](http://localhost:8080/libtrackerboy/)

## Deploying
 1. `npm install`
 1. `npm build`
 1. The production built site is located in the `_site` folder and can be
    deployed to github pages.

## Site structure

 - `/` - main page, gives a summary, how to use, and a list of recent releases
 - `/404.html/` - HTTP 404 page, shown when user tries to access a non-existing page
 - `/releases/` - Shows the full history of releases
 - `/releases/<version>/` - Shows information about a release where `<version>`
   is the git tag of the release
 - `/docs/<version>/` - Documentation for a release. Note that the
   `/docs/<version>/index.html` will redirect to
   `/docs/<version>/libtrackerboy.html`

## Adding a release

CI should do this automatically, but here is the process for adding a release:
```sh
./ci.py release <pathToDocs> <tag> <pathToChangelog>
```
Where:
   - `pathToDocs` is the path to the generated html documentation for this release
   - `tag` is the tag name of the release
   - `pathToChanglog` is the path of libtrackerboy's changelog

### Removing a release

If a release needs to be removed for whatever reason, use this command and
commit changes:
```sh
./ci.py remove <tag>
```

## Updating `develop` documentation

The `develop` branch shows up in the releases table, and contains the generated
documentation for the latest commit in that branch. CI will also do this
automatically, but for manual updates run the following command:

```sh
./ci.py develop <pathToDocs>
```

Where `pathToDocs` is the path of the generated html documentation for the 
`develop` branch.
