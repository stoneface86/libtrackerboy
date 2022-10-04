#!/usr/bin/env python3

# Continuous integration script for updating documentation and adding a page
# to the releases collection
#
# Examples:
# ./ci.py develop path-to-generated-docs
# ./ci.py release path-to-denerated-docs release-tag path-to-changelog


import argparse, os, sys, shutil

SCRIPT_PATH = os.path.dirname(os.path.realpath(__file__))
DOCS_PATH = os.path.join(SCRIPT_PATH, 'docs')
RELEASES_PATH = os.path.join(SCRIPT_PATH, '_releases')
del SCRIPT_PATH

def docsPathOf(tag):
    return os.path.join(DOCS_PATH, tag)

def releasesPageOf(tag):
    return os.path.join(RELEASES_PATH, f'{tag}.md')

def updateDocs(docpath: str, tag: str):
    dest = docsPathOf(tag)
    if os.path.exists(dest):
        shutil.rmtree(dest)
    os.makedirs(DOCS_PATH, exist_ok=True)
    shutil.copytree(docpath, dest)
    with open(os.path.join(dest, 'index.html'), 'w') as f:
        f.write(
'''---
layout: docs_redirect
---
'''
        )

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


def release(args):
    with open(args.changelog, 'r') as changelogFile:
        date = findTagInChangelog(changelogFile, args.tag)
        if date is None:
            print("error: could not find", args.tag, "in", args.changelog)
            return 1
        
        with open(releasesPageOf(args.tag), 'w') as releaseFile:
            releaseFile.write(f'''---
layout: release
title: {args.tag}
date: {date}
---
''')
            while line := changelogFile.readline():
                tokens = line.split(maxsplit=1)
                if len(tokens) == 2 and tokens[0] == "##":
                    break
                releaseFile.write(line)  
    updateDocs(args.docspath, args.tag)
    return 0

def remove(args):
    shutil.rmtree(docsPathOf(args.tag), ignore_errors=True)
    releasePage = releasesPageOf(args.tag)
    if os.path.exists(releasePage):
        os.remove(releasePage)
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
