---
layout: post
title: 10 Advanced Git Tips
subtitle: Improve your developer workflow
---

Git is a topic that I am particularly interested in. It's a tool that we use every day, but many people just scratch the surface of what Git can do in their day-to-day routines. Here's a list of 10 useful tips and tricks that are more advanced.

1. You can see your stashed changes with `git stash list`, which might return an output that looks like this:

   ```
   stash@{0}: WIP on master: aeee31b Merge pull request #1 in ...
   ```

   Here I have a single item in the stash which is at position 0. To apply the changes I stashed, you can use `git stash apply stash@{0}` which will apply and leave the changes in the stash. If you don't like training wheels, you can use `git stash pop stash@{0}` to apply and delete. Manually deleting a stashed item can be done with `git stash drop stash@{0}`. For any of these commands, you would replace the number 0 with whichever of the (possibly multiple) stashed items you want to apply.

2. You can use `git archive` to compress your versioned code

`git archive --format zip --output master_branch.zip master`

`git archive --format zip --output version_0.1.1.zip "0.1.1"`

Supports a lot of formats and you can provide a number of refs as the last argument for what you want to compress. The first example I gave uses the master branch, but you could also provide a commit hash or a tag.

3. The `.git` folder

All of the information that defines a git repo is stored inside a hidden .git folder inside your repo. You can delete this folder to make the project “forget” it lives in a repo. You can also explore this folder to see what all is stored there including refs and blobs. For example every branch is stored as a text file that’s contents just contain the commit hash it points to.

4. `git log --pretty`

The `--pretty` switch in `git log` can be used to specify a format with many different options. You can use this to capture the hash of a particular commit in a variable and then reuse it elsewhere, such as in a CI job.

```
hash=$(git log -n 1 --pretty=format:'%H')
echo "The hash is ${hash}"
```

> The hash is 5465dXXXX

5. `git commit --amend`

If you just finished a commit a realize you accidentally had staged a new file you didn't intend to commit, an easy way to undo this is:

`git rm --cached <file to remove>`

`git commit --amend`

Note this was for a _new_ file, as `git rm --cached` will remove the file from the index, and then `git commit --amend` recreates a single, unified commit.

6.

7.

8. Undo committed changes to a single file

If you accidentally commit changes to an existing file that you want to undo, then there are many ways to resolve, but I would prefer:
`git reset HEAD^ <file>`
`git commit --amend`

9. 10.
