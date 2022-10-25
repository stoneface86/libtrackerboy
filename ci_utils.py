# -----------------------------------------------------------------------------
# ci_utils.py
# Version: 1.0.0
#
# Utility module for updating releases for a website from continuous
# integration. Contains a parser for a changelog, which extracts version, date
# and changes from a changelog for a specific version.
#
# Typical use of this module is to use a ChangelogParser to extract a single
# Release object for a given version and then dump it to a JSON file via the
# ReleaseStore class. This JSON file is then used by a static site generator
# (ie 11ty) and templates for building a web page for that release.
#
# The ChangelogParser assumes the format to be the one specified by
# https://keepachangelog.com/en/1.0.0/, the changelog below is also in this
# format as an example.
#
# Application of this module is incredibly niche and likely will not suit your
# needs. Shared publically as a gist in the rare case that it does.
#
# Requires Python 3.6 or greater
#
# Author: Brennan Ringey (stoneface86)
#
# # Changelog
#
# ## [1.0.0] - 2022-10-25
# Initial version
#
# -----------------------------------------------------------------------------
# MIT License
# 
# Copyright (c) 2022 Brennan Ringey
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 

import json, os
from typing import NamedTuple, Iterator


class Release(NamedTuple):
    tag: str
    date: str
    changes: str

    def jsonify(self) -> dict:
        return {
            "version": self.tag,
            "date": self.date,
            "changes": self.changes
        }


class Asset(NamedTuple):
    name: str           ## name of the asset
    method: str         ## method of obtaining the asset {'github-asset', 'url'}
    methodParam: str    ## url, or filename of the github asset

    def jsonify(self) -> dict:
        return {
            "name": self.name,
            self.method: self.methodParam
        }


class ChangelogParser(object):

    __slots__ = ('__fp', '__path', '__curTagDate')

    def __init__(self, path):
        self.__fp = None
        self.__path = path
        self.__curTagDate = None

    def __enter__(self):
        self.__fp = open(self.__path, 'r')
        return self
    
    def __exit__(self, *args):
        self.__fp.close()
        self.__fp = None
    
    def nextTag(self) -> bool:
        while line := self.__fp.readline():
            tokens = line.split()
            # 4 tokens: "##", "[version]", "-", "date"
            if len(tokens) == 4 and \
                tokens[0] == "##" and \
                tokens[2] == "-":
                if len(tokens[1]) > 2 and tokens[1][0] == '[' and tokens[1][-1] == ']':
                    self.__curTagDate = (tokens[1][1:-1], tokens[3])
                    return True
        return False
    
    def takeChanges(self) -> str:
        changes = []
        while True:
            tell = self.__fp.tell()
            line = self.__fp.readline()
            if line == "":
                break
            tokens = line.split(maxsplit=1)
            if len(tokens) == 2 and tokens[0] == "##":
                self.__fp.seek(tell)
                break
            changes.append(line)
        return ''.join(changes).strip()

    @property
    def tag(self) -> str:
        return self.__curTagDate[0]

    @property
    def date(self) -> str:
        return self.__curTagDate[1]


def extractAllFromChangelog(path) -> Iterator[Release]:
    with ChangelogParser(path) as p:
        while p.nextTag():
            yield Release(f'v{p.tag}', p.date, p.takeChanges())


def extractReleaseFromChangelog(path, tag: str) -> Release:
    version = tag[1:]
    with ChangelogParser(path) as p:
        while p.nextTag():
            if p.tag == version:
                return Release(tag, p.date, p.takeChanges())
    return None

class ReleaseStore(object):

    __slots__ = ('__path', )
    
    def __init__(self, path: str):
        self.__path = path

    def pathOfRelease(self, tag: str) -> str:
        return os.path.join(self.__path, f'{tag.replace(".", "_")}.json')

    def add(self, release: Release, **extra) -> None:
        obj = release.jsonify()
        obj.update(extra)
        os.makedirs(self.__path, exist_ok=True)
        with open(self.pathOfRelease(release.tag), 'w') as fp:
            json.dump(obj, fp, indent=2)
    
    def remove(self, tag: str) -> None:
        releasePath = self.pathOfRelease(tag)
        if os.path.exists(releasePath):
            os.remove(releasePath)


class AssetList(object):

    __slots__ = ('__map', )

    def __init__(self):
        self.__map = {}

    def put(self, asset: Asset) -> None:
        self.__map[asset.name] = asset

    def jsonify(self) -> dict:
        return { 
            'assets': [ asset.jsonify() for asset in self.__map.values() ]
        }

if __name__ == "__main__":
    import unittest

    class TestAssetList(unittest.TestCase):
        def test_empty(self):
            self.assertEqual(AssetList().jsonify(), {'assets': []})
        
        def test_one(self):
            al = AssetList()
            al.put(Asset('linux64', 'github-asset', 'my-asset-linux-x64.tar.gz'))
            self.assertEqual(al.jsonify(), {
                'assets': [
                    {
                        'name': 'linux64',
                        'github-asset': 'my-asset-linux-x64.tar.gz'
                    }
                ]
            })


    unittest.main()
