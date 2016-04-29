# Ink

Ink is an abstraction layer and git-powered tooling around infrastructure provisioning.

It wraps common provisioning tools with a standard workflow that ensures
infrastructure changes are all tracked in git.

## Why use Ink

There are many tools and technologies you could use for provisioning
infrastructure, but not all of them have a very well defined workflow. Ink
makes the assumption that not only do you want to programmatically interact
with your infrastructure (which is why you're using these tools in the first
place), but you also want to have a workflow that tracks your infrastructure
changes as code.

## Installation

You'll likely want to run ink on some coordinator host in your production
network (meaning, not locally).

Really all you need is a workspace for ink to do it's work, and whatever
environment variables needed for your provisioning scripts to do the work they
need.

For example, if you create some space in `/var/lib/ink`, just make sure you run
ink inside this path and you're good to go.

### Local Installation

Ok fine, you can run this on your laptop in your development environment if you want.

The difference is going to be you are going to manage the clone of the repo yourself.

Run ink from inside the repository. You might need to start with:

    $ ink init .

## Hooks

The most imporant part of using Ink is how to build your repository so it can
be maintained by Ink. The entire API is based on:

  1. Specially named scripts
  2. stdout from these specially named scripts
  3. Passing environment variables

### The scripts

Each script cooresponds to the ink sub-command you will call. With few
exceptions, stdout/stderr from these scripts will be passed along to the
caller. In most cases, if the script doesn't exist, or returns an exit code,
the operation will stop.

  * `script/ink-init`
  * `script/ink-create`
  * `script/ink-update`
  * `script/ink-plan`
  * `script/ink-show`
  * `script/ink-destroy`


## How it works

Ink is based on git repositories. Ink calls hooks inside the repo to abstract
away the real tooling that will make infrastructure changes. The revision
history of the repository then becomes the revision history of your
infrastructure.

Each Ink stack is a branch in your repository. For example, let's say you
create a new stack based on your octobatman repository:

    $ ink init git@github.com:github/octobatman.git
    octobatman-d88f7

If you check your repository, you'll see one very important thing: A new branch
called `octobatman-d88f7`

Now when we start making use of this stack, we're actually just making changes
in our branch and again calling hooks.

    $ ink create octobatman-d88f7

This command will:

  1. Verify our branch `octobatman-d88f7` is at HEAD
  2. Create a new file in that branch called `.ink.yaml`
  3. Execute your own script `script/ink-create`
  4. Commit any changes and push to origin.

What happens inside `ink-create` is up to you, but you could for example use a
tool like Terraform to build a web server in AWS. You could then store the
state file in your repository.

Now, what happens when we want to make changes to our infrastructure? Depends
on the tool, but essentially you make the changes in whatever configuration
file your tool uses, then commit it to `origin/master`.

    $ ink update octobatman-d88f7

This command will then:

  1. Verify our branch `octobatman-d88f7` is at HEAD
  2. Merge in origin/master
  3. Execute your own script `script/ink-update`
  4. Commit any changes and push to origin.

## The Provisioners

I can already hear you saying it. "Ugh, this doesn't actually DO anything".
You're right, ink is basically just calling some scripts that you have to write
and wrapping them around some simple git operations.

BUT... what if I told you the scripts for those provisioners already existed!

Boom, checkout [examples/](examples/) for more.
