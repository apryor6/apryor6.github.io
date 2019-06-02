---
layout: post
title: 10 Advanced Git Tips
subtitle: Improve your developer workflow
tags: [git, tips, tutorial]
---

Git is an amazing piece of technology. It's a tool that we use every day, but many people just scratch the surface of what Git can do in their day-to-day routines. Here's a list of 10 useful tips and tricks that are more advanced.

### 1. You can see your stashed changes with `git stash list`, which might return an output that looks like this:

```
stash@{0}: WIP on master: aeee31b Merge pull request #1 in ...
```

Here I have a single item in the stash which is at position 0. To apply the changes I stashed, you can use `git stash apply stash@{0}` which will apply and leave the changes in the stash. If you don't like training wheels, you can use `git stash pop stash@{0}` to apply and delete. Manually deleting a stashed item can be done with `git stash drop stash@{0}`. For any of these commands, you would replace the number 0 with whichever of the (possibly multiple) stashed items you want to apply.

### 2. You can use `git archive` to compress your versioned code

`git archive --format zip --output master_branch.zip master`

`git archive --format zip --output version_0.1.1.zip "0.1.1"`

Supports a lot of formats and you can provide a number of refs as the last argument for what you want to compress. The first example I gave uses the master branch, but you could also provide a commit hash or a tag.

### 3. The `.git` folder

All of the information that defines a git repo is stored inside a hidden .git folder inside your repo. You can delete this folder to make the project “forget” it lives in a repo. You can also explore this folder to see what all is stored there including refs and blobs. For example every branch is stored as a text file that’s contents just contain the commit hash it points to.
Inside of `.git/refs/` you will find `heads/`, `tags/`, and, unless your repo is local-only, `remotes/`. `.git/refs/heads/` will contain one entry per branch (either a file or a folder if you have branch names with slashes -- the branch `topic/feature1` will exist as `.git/refs/heads/topic/feature1`). If you inspect the contents of any of these files they just contain the commit hash they point to (read: "REFerence"). Similarly, inside of tags you will find any tags you add (like we did the other day to atdcoe). Inside of remotes you will find another folder for each remote. Usually you will have `origin`, and you may have additional remotes such as `upstream` if you have forked a repository and then cloned your fork locally, which is the common open-source workflow. Note that refs for the remote are stored statically in your local git repo -- there is no way for this to remain constantly aware of changes that occur in the actual remote repository. This is why if you want to checkout or merge from a remote branch you must do a `git fetch` or a command that includes fetching like `git pull`. The fetch step updates `.git/refs/remotes/`, and the effect is that you are now aware of the latest changes in the remote and can checkout or merge accordingly.

### 4. `git log --pretty`

The `--pretty` switch in `git log` can be used to specify a format with many different options. You can use this to capture the hash of a particular commit in a variable and then reuse it elsewhere, such as in a CI job.

```
hash=$(git log -n 1 --pretty=format:'%H')
echo "The hash is ${hash}"
```

> The hash is 5465dXXXX

### 5. `git commit --amend`

If you just finished a commit a realize you accidentally had staged a new file you didn't intend to commit, an easy way to undo this is:

`git rm --cached <file to remove>`

`git commit --amend`

Note this was for a _new_ file, as `git rm --cached` will remove the file from the index, and then `git commit --amend` recreates a single, unified commit.

### 6. Use `git revert` to undo shared history

Use `git revert <commit hash>` to undo a commit. This creates a _new commit_ that does the opposite of the target commit(s). This is useful when you have identified a problem commit (such as with `git blame`) and need to reverse it but you do not want to modify the history of the repository because it is shared.

A followup to that is a sort of golden rule for git -- "Never modify history that is shared."

You can modify, rewrite, rebase, etc your own history however you would like, but once you have merged those changes into a branch that is shared by others it will cause huge problems if you modify history because other users are not aware of it. If you ever encounter something mentioning that you _could_ force push you are likely flirting with disaster.

Rewriting your own history, however, can be an awesome way to neaten things up. When working on a feature you could just commit all the time with small changes so that you have frequent "save points", and then once the feature is done you simply rebase those commits to form a couple of nice, complete changes as if you made all the steps in one go.

### 7. Find broken commits with `git bisect`

`git bisect` is a binary search algorithm with a bajillion variations for finding the problem commit that introduced a bug. The most common way you will use it is to be on the branch where the code has a problem and invoke `git bisect start` followed by `git bisect bad`. This will mark the current commit as a known problem commit. Next, invoke `git bisect good <hash of valid commit in past>` where you choose a commit that is known to be stable. Git will then split that range of commits in half and checkout the midpoint commit, at which point you will invoke either `git bisect good` or `git bisect bad` to indicate the status of that commit. This process repeats until there is only one possible commit remaining which then yields the point where the bug was introduced.

### 8. Undo committed changes to a single file

If you accidentally commit changes to an existing file that you want to undo, then there are many ways to resolve, but I would prefer:
`git reset HEAD^ <file>`
`git commit --amend`

### 9. Use the `--` operator to disambiguate command arguments from refs

For example, suppose you are Satan and you create a file named "-p" and then you attempt to add it with `git add -p`. This will not add the file because `git` thinks that you are using the `-p` switch in git add. To actually add the file, you could use `git add -- -p`. Although contrived, this need arises more practically in cases such as when you use `git checkout`, as you may frequently find yourself checking out a branch or a single file from another branch.

### 10. Use `git reflog` to recover deleted branches

Branch deletion removes the REFERENCE to the blob (git-speak for memory containing the commit), but that blob is not actually cleaned up until git's garbage collector runs, which is usually not for days or weeks by default. As long as you can figure out what the commit hash was for the tip of the branch you just deleted, you can easily recreate the branch.

How do you figure out the commit hash of a branch that is no longer there because you just deleted it? You can use `git reflog`, which tracks the movement of HEAD.

I invoked `git reflog | grep branch_name`:

```
fe2fc1b HEAD@{39}: checkout: moving from topic/feature1 to branch_name
```

Which reveals that 39 movements ago I checked out `branch_name`

Then getting back my branch is one line: `git checkout -b branch_name fe2fc1b`
