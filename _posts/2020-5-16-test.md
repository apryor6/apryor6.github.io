---
layout: post
title: Easy Deployment of Python Google Cloud Functions using setuptools
subtitle: Bundling archives for programmatic deployment
tags:
  [python, gcp, gcf, google cloud, dev ops, serverless, software engineering]
---

_The takeaway from this post is that with one command, `invoke deploy_gcs`, you will be able to bundle a python package into and archive and deploy a GCF against that_

At [Torqata](https://torqata.com/), we work heavily within Google Cloud Platform, and we spend quite a bit of effort to the end of making our dev ops process more seamless, consistent, easy to use, and automated wherever possible. For example, we use a monorepo structure that houses our Angular and Python code with custom build tools that extend the _awesome_ utility of the Nrwl [Nx](https://nx.dev/) CLI to work the same with Python. In addition, we wrap almost all of our "actions" into [Invoke](http://www.pyinvoke.org/) tasks (or, rather, a modified version of Invoke that allows us to work within our monorepo and target various projects). I would love to write more about many of these topics, as there is a lot of information and code that would be useful to a broader audience, but today I wanted to focus in sharing one useful tidbit relating to deploying Google Cloud Functions.

If you are not aware, [Google Cloud Functions](https://cloud.google.com/functions) are GCP's serverless code snippet deployment offering very similar to [AWS Lambda](https://aws.amazon.com/lambda/) and [Microsoft Azure Functions](https://azure.microsoft.com/en-us/services/functions/). It supports a few different runtimes (Node, Python, Go, etc) and a few different ways to actually provide your code. Usually the easiest way to get up and running with GCF is to use the inline code editor and copy/paste snippets of code that you want to run. However, inevitably at some point you will want a more stable/repeatable deployment pattern that can be programmatic and tied to source control or versioned artifacts in a way that you can actually reason about.

The best way to do this is to point the GCF to deploy from a .zip archive within a GCS bucket. This allows you to have an externally available source of the archive, avoiding the problem of deployments differing from one users machine to another. But how to best create this archive? It has to conform to a certain structure, and although you could write a Makefile or bash script to grab the dependencies, there is a better way -- you can just use Python's existing packaging mechanism, `setuptools`! After all, why reinvent the wheel..

To do this, start by creating a package with your code. If you haven't done this before with making a `setup.py`, refer [to the documentation](https://packaging.python.org/tutorials/packaging-projects/). For this post, I'll assume you have that part down. Next, GCF requires that the entry code be in a file `main.py`. To solve for this, I add a `main.py` file at the same level of the project as the `setup.py`, and this file imports from my package the function(s) that I want to expose to GCF. Effectively, this is like a barrel file that exposes the functions you care about. To ensure this file gets bundled into the source distribution, create a `MANIFEST.in` file with an `include main.py` record. Also, create a `requirements.txt` file with the dependencies and add `include requirements.txt` to the manifest. Note that _normally_ you would include dependencies in the `setup.py` file so that pip installing your package fetched them, and you may also have the dependencies there if you use this package elsewhere, but for GCF specifically we also must have a requirements.txt as that is how it will install. Remember, this process is using the existing packaging toolset for a purpose other than it's direct intent, so it isn't a "normal" package.

The last consideration to handle is that when you run `python setup.py sdist` the resulting distribution archive will contain the code wrapped inside a directory with the same name as the package. We will need to unpack this one level so that the `main.py` file is at the top of the archive.

Ok, with all of that said. Here is the single `invoke` task that will accomplish all of the above.

```python
@task
def deploy_gcf(ctx, dst_bucket):
    """Deploy Google Cloud Function source code to dst_bucket"""
    with ctx.cd(f"<YOUR PACKAGE DIRECTORY>"):
        with tempfile.TemporaryDirectory() as tmpdirname:
            # Create source distribution
            ctx.run(f"python setup.py sdist --formats=zip --dist-dir {tmpdirname}")
            with ctx.cd(tmpdirname):
                # The archive is nested inside a folder with the same name as package,
                # but GCF needs it to be unnested, so here we unzip/rezip with correct
                # structure
                archive = [f for f in os.listdir(ctx.cwd) if f.endswith(".zip")][0]
                root, _ = os.path.splitext(archive)
                ctx.run(f"unzip {archive}")
                with ctx.cd(root):
                    ctx.run(f"zip -r {archive} * -x *.egg-info")
                    # Copy archive to the deploy bucket
                    ctx.run(f"gsutil cp {os.path.join(ctx.cwd, archive)} {dst_bucket}")
    ctx.run(
        f"""gcloud functions deploy [GCF NAME] --region=[MY REGION] --entry-point=[FUNCTION TO RUN] \
            --runtime=python37 --source={dst_bucket}/{archive} --max-instances=1 """
    )

```

A few things worth commenting on. I use `tempfile.TemporaryDirectory` to get a cross-platform reference to an ephemeral storage area. I don't actually intend to keep the archive around, so it only needs to live long enough to copy it to GCS. I use the `dst-dir` flag to specifify this directory as the target, and then `cd` into it to unzip/rezip the file for the correct structure before finally copying to GCS. It might seem kind of silly to be unzipping and rezipping, but keep in mind we didn't have to write any code for actually tracking down the source files and bundling them other than creating a couple of entries in the MANIFEST.in. Finally, we deployed the function with a `gcloud` command.

Finally, to actually run this is as simple as `invoke deploy-gcs`, which will be up and running in less than a minute. Super simple, repeatable, and can be versioned based upon the package's `setup.py`!