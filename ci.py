#!/usr/bin/env python3

# Continuous integration script for updating documentation and adding a page
# to the releases collection
#
# Examples:
# ./ci.py develop path-to-generated-docs
# ./ci.py release path-to-denerated-docs release-tag path-to-changelog

assert __name__ == "__main__", "script cannot be imported"

import argparse, os, sys, shutil
from ci_utils import extractReleaseFromChangelog, ReleaseStore

class Program(object):

    __slots__ = ("__docRedirectPath", "__docsPath", "store")

    def __init__(self):
        scriptPath = os.path.dirname(os.path.realpath(__file__))
        self.__docsPath = os.path.join(scriptPath, 'src/docs')
        self.__docRedirectPath = os.path.join(scriptPath, 'src/pages/docRedirects')
        self.store = ReleaseStore(os.path.join(scriptPath, 'src/_data/releasesByTag'))
    
    def redirectTemplatePathOf(self, tag):
        '''
        Returns the path of the redirect template for the given tag. ie,
        redirectTemplatePathOf('v0.1.1') would result in
        "<PARENT_DIR_OF_SCRIPT>/src/pages/docRedirects/v0.1.1.md"
        '''
        return os.path.join(self.__docRedirectPath, f'{tag}.md')
    
    def addRedirectTemplate(self, tag):
        '''
        Adds a docs redirect template for the given tag. Since nim docgen doesn't
        generate an index.html, this template will generate one that simply redirects
        to the main page.
        '''
        with open(self.redirectTemplatePathOf(tag), 'w') as f:
            f.write(f'''---
layout: layouts/docsRedirect.html
permalink: /docs/{tag}/
---
'''
            )
    
    def docsPathOf(self, tag):
        '''
        Returns the path of the documentation for the given tag. ie, docsPathOf('v0.1.1')
        would result in "<PARENT_DIR_OF_SCRIPT>/docs/v0.1.1"
        '''
        return os.path.join(self.__docsPath, tag)

    def updateDocs(self, docpath: str, tag: str):
        '''
        Replaces the ./docs/{tag} folder with the given directory. Also adds a
        redirect template to ./src/docRedirects
        '''
        dest = self.docsPathOf(tag)
        if os.path.exists(dest):
            shutil.rmtree(dest)
        os.makedirs(self.__docsPath, exist_ok=True)
        shutil.copytree(docpath, dest)
        self.addRedirectTemplate(tag)

def develop(prog: Program, args) -> int:
    prog.updateDocs(args.docspath, 'develop')
    return 0

def release(prog: Program, args) -> int:
    releaseToAdd = extractReleaseFromChangelog(args.changelog, args.tag)
    if releaseToAdd is None:
        print("error: could not find", args.tag, "in", args.changelog)
        return 1
    prog.store.add(releaseToAdd)
    prog.updateDocs(args.docspath, args.tag)
    return 0

def remove(prog: Program, args) -> int:
    shutil.rmtree(prog.docsPathOf(args.tag), ignore_errors=True)
    redirectPath = prog.redirectTemplatePathOf(args.tag)
    if os.path.exists(redirectPath):
        os.remove(redirectPath)
    prog.store.remove(args.tag)
    return 0


def main() -> None:

    parser = argparse.ArgumentParser()
    subs = parser.add_subparsers(required=True, help='sub-command help')

    developParser = subs.add_parser('develop', help='Update develop branch documentation')
    developParser.add_argument('docspath', help="Path to the generated documentation")
    developParser.set_defaults(subcmd=develop)

    releaseParser = subs.add_parser('release', help="Add a new release")
    releaseParser.add_argument('docspath', help="Path to the generated documentation")
    releaseParser.add_argument('tag', help='Release tag to add')
    releaseParser.add_argument('changelog', help='Path to CHANGELOG.md')
    releaseParser.set_defaults(subcmd=release)

    removeParser = subs.add_parser('remove', help='Removes a previously added release')
    removeParser.add_argument('tag', help='Release tag to remove')
    removeParser.set_defaults(subcmd=remove)

    args = parser.parse_args()
    sys.exit(args.subcmd(Program(), args))

main()
