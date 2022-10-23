#!/usr/bin/env python3

# Continuous integration script for updating documentation and adding a page
# to the releases collection
#
# Examples:
# ./ci.py develop path-to-generated-docs
# ./ci.py release path-to-denerated-docs release-tag path-to-changelog


import argparse, json, os, sys, shutil

SCRIPT_PATH = os.path.dirname(os.path.realpath(__file__))
DOCS_PATH = os.path.join(SCRIPT_PATH, 'src/docs')
RELEASES_JSON_PATH = os.path.join(SCRIPT_PATH, 'src/pages/pages.11tydata.json')
DOCS_REDIRECT_PATH = os.path.join(SCRIPT_PATH, 'src/pages/docRedirects')
del SCRIPT_PATH

def docsPathOf(tag):
    '''
    Returns the path of the documentation for the given tag. ie, docsPathOf('v0.1.1')
    would result in "<PARENT_DIR_OF_SCRIPT>/docs/v0.1.1"
    '''
    return os.path.join(DOCS_PATH, tag)

def redirectTemplatePathOf(tag):
    '''
    Returns the path of the redirect template for the given tag. ie,
    redirectTemplatePathOf('v0.1.1') would result in
    "<PARENT_DIR_OF_SCRIPT>/src/pages/docRedirects/v0.1.1.md"
    '''
    return os.path.join(DOCS_REDIRECT_PATH, f'{tag}.md')

def addRedirectTemplate(tag):
    '''
    Adds a docs redirect template for the given tag. Since nim docgen doesn't
    generate an index.html, this template will generate one that simply redirects
    to the main page.
    '''
    with open(redirectTemplatePathOf(tag), 'w') as f:
        f.write(f'''---
layout: layouts/docsRedirect.html
permalink: /docs/{tag}/
---
'''
        )

def updateDocs(docpath: str, tag: str):
    '''
    Replaces the ./docs/{tag} folder with the given directory. Also adds a
    redirect template to ./src/docRedirects
    '''
    dest = docsPathOf(tag)
    if os.path.exists(dest):
        shutil.rmtree(dest)
    os.makedirs(DOCS_PATH, exist_ok=True)
    shutil.copytree(docpath, dest)
    addRedirectTemplate(tag)

def develop(args):
    updateDocs(args.docspath, 'develop')
    return 0

def findTagInChangelog(f, tag):
    version = tag[1:]
    while line := f.readline():
        tokens = line.split()
        # 4 tokens: "##", "[version]", "-", "date"
        if len(tokens) == 4 and \
           tokens[0] == "##" and \
           tokens[1][1:-1] == version and \
           tokens[2] == "-":
           return tokens[3]
    return None

class Store(object):
    '''
    JSON store for releases. Each release is stored in the json file,
    RELEASES_JSON_PATH, and can be modified using this class via a with
    statement. 
    '''

    def __init__(self):
        self.__store = []
        self.__storeDirty = False
        self.__fp = None

    def __enter__(self):
        self.__fp = open(RELEASES_JSON_PATH, 'r+')
        store = json.load(self.__fp)
        assert len(store) == 1 \
               and 'releases' in store \
               and isinstance(store['releases'], list)
        self.__store = store['releases']
        self.__storeDirty = False
        return self

    def __exit__(self, *args):
        if self.__storeDirty:
            self.__fp.seek(0, 0)
            json.dump({ 'releases': self.__store }, self.__fp)
            self.__fp.truncate()
        self.__fp.close()

    def push(self, tag, date, changes):
        '''
        Pushes a release entry to the front of the store.
        '''
        self.__store.insert(0, {
            'version': tag,
            'date': date,
            'changes': changes
        })
        self.__storeDirty = True
    
    def remove(self, tag):
        '''
        Removes a release whoses version field matches tag, if exists.
        '''
        index = next((x for x in self.__store if x['version'] == tag), -1)
        if index != -1:
            self.__store.remove(index)
            self.__storeDirty = True



def release(args):
    with open(args.changelog, 'r') as changelogFile:
        date = findTagInChangelog(changelogFile, args.tag)
        if date is None:
            print("error: could not find", args.tag, "in", args.changelog)
            return 1
        
        # extract the changes from the changelogFile
        changes = []
        while line := changelogFile.readline():
            tokens = line.split(maxsplit=1)
            if len(tokens) == 2 and tokens[0] == "##":
                break
            changes.append(line)
        # push the release to the json store
        with Store() as store:
            store.push(args.tag, date, '\n'.join(changes))

    updateDocs(args.docspath, args.tag)
    return 0

def remove(args):
    shutil.rmtree(docsPathOf(args.tag), ignore_errors=True)
    redirectPath = redirectTemplatePathOf(args.tag)
    if os.path.exists(redirectPath):
        os.remove(redirectPath)
    with Store() as store:
        store.remove(args.tag)
    return 0


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    subs = parser.add_subparsers(help='sub-command help')

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
    sys.exit(args.subcmd(args))
