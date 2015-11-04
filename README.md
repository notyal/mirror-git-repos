mirror-git-repos
----------------

```
mirror.sh: Keep a set of git mirrors up to date.
Copyright (c) 2015 Layton Nelson <notyal.dev@gmail.com>

USAGE: ./mirror.sh [OPTION]...

OPTIONS:
  archive                Archive the repos.
  create <url>           Add a repo to the mirror directory.
  backup-gh-user <user>  Backup all repos associated with a user on Github.
  delete <repo>          Remove a repo from the mirror directory.
  list                   List mirrors in the mirror directory.
    -a, --absolute       Show the absolute path for the location of each mirror.
  path                   Show the mirror directory location.
  update                 Update the list of mirrors in the mirror directory.
  query <user>           Query the Github API for a list of repos associated
                         with the provided user.
  help                   Show this help.
```

## License

```
Copyright (c) 2015 Layton Nelson <notyal.dev@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
