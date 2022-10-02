
# libtrackerboy gh-pages

This branch is used for github pages. Jekyll is used to build the web site.
The site will just display a basic summary of the project, as well as
release information and to host the documentation.

## Testing locally
 1. Install ruby
 1. `gem install bundler`
 1. `bundle install`
 1. `bundle exec jekyll serve`
 1. Test the site via [http://localhost:4000](http://localhost:4000)

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

 - Add a `<version>.md` page to the `_releases` directory
   - `version` is the tag name of the release (ie `v1.0.0`)
   -  the front matter must have a `date` and `version` field, use the release
      layout for the page.
   - The page's content should be the changes for that version from CHANGELOG.md
 - Add the generated documentation for this release to `docs/<version>/`
 - Add an `index.html` page with no content to `docs/<version>` with
   `layout: docs_redirect` in the front matter.

## Updating `develop` documentation

The `develop` branch shows up in the releases table, and contains the generated
documentation for the latest commit in that branch. To update the documentation,
follow the same instructions of adding a release but instead replace the
contents of `docs/develop` with the generated documentation. Same with adding a
release, CI should handle this automatically.
