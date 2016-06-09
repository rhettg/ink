# Ink

Ink is a tool for "GitOps".

Ink enables you to track infrastructure and operational changes in git.
Ink provides a workflow that allows you wrap other "infrastructure as code"
technologies and avoid non-code operational tasks such as running a
command on a host.

## Why use Ink

There are many tools and technologies you could use for operating computing
infrastructure, but not all of them have a very well defined multi-user workflow.

It's great that you can use a technology like Terraform to specify to
configure in AWS 1 VPC, 4 subnets, 300 hosts, 4 load balancers, 99 security
groups and instance profiles. But if one "adminstrator" has to login to a
machine to run a command to update the configuration that is still "ops".

You can take those commands and build
["ChatOps"](https://www.youtube.com/watch?v=NST3u-GjjFw). This has benefits
like visibility (other engineers can see and learn from the work taking place)
and some amount of auditing (you can search your chat logs).

Ink takes this one step further and wraps the "ops" process under
revision control just like any other code.

## Installation

You'll likely want to run ink on some coordinator host in your production
network (meaning, not locally).

All you need is a workspace for ink to clone git repositories and some
environment variables needed for your scripts to do the work they need.

Create a space like `/var/lib/ink`, and make sure you always run ink inside
this path.

### Local Installation

Ok fine, you can run this on your laptop in your development environment if you want.

The difference is going to be you are going to manage the clone of the repo
yourself. Ink is also going to ignore if the repo has a remote at all.

Run ink from inside the repository starting with:

    $ ink init .

## Hooks

Ink will look for specially named scripts in your repository to execute.

The entire API for integrating with Ink is:

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

Each Ink "stack" is a branch in a repository. For example, let's say you
create a new stack based on your octobatman repository:

    $ ink init git@github.com:github/octobatman.git
    octobatman-d88f7

If you check your repository, you'll see one very important thing: A new branch
called `ink-octobatman-d88f7`

Now when we start making use of this stack, we're actually just making changes
in our branch and again calling hooks.

    $ ink create octobatman-d88f7

This command will:

  1. Verify our branch `ink-octobatman-d88f7` is at HEAD
  2. Merge in origin/master
  3. Create a new file in that branch called `.ink-env`
  4. Execute your own script `script/ink-create`
  5. Commit any changes and push to origin.

What happens inside `ink-create` is up to you, but you could for example use a
tool like Terraform to build a web server in AWS. You could then store the
state file in your repository.

Now, what happens when we want to make changes to our infrastructure? Depends
on the tool, but you'll put whatever steps are necessary in your `ink-update`
script.

    $ ink update octobatman-d88f7

This command will then:

  1. Verify our branch `ink-octobatman-d88f7` is at HEAD
  2. Merge in origin/master
  3. Execute your own script `script/ink-update`
  4. Commit any changes and push to origin.

## Environment

When initializing an ink stack you can provide arguments. These will be
persisted in git and provided to ink scripts when executed. For example:

    $ ink init git@github.com:github/octobatman.git MY_VAR=foo
    octobatman-d88f7

Your `script/ink-create` can then reference the variable just like any environment variable.

    #!/bin/bash
    echo "$MY_VAR"

When you run `ink create` you'll see:

    $ ink create octobatman-d88f7
    foo

There are also some useful built-in environment variables that can be used by your scripts:

  * `INK_NAME` - The name of your ink stack, for example `octobatman-d88f7` in the above examples.

## Custom Name

You can customize the naming by specifying the special `ID` variable.

    $ ink init git@github.com:github/octobatman.git ID=production
    octobatman-production

Or you can completely override the naming system by using the above envionment facilities

    $ ink init git@github.com:github/octobatman.git INK_NAME=alfred
    alfred

## The Providers

I can already hear you saying it. "Ugh, this doesn't actually DO anything".
You're right, ink is basically just calling some scripts that you have to write
and wrapping them around some simple git operations.

BUT... what if I told you some of these scripts were already written for you!

Boom, checkout [providers/](providers/) for more.

## Development

We Test.
Build Status: [![Circle CI](https://circleci.com/gh/rhettg/ink.svg?style=svg)](https://circleci.com/gh/rhettg/ink)

### TODO

  - [ ] More helpful ink-env vars
  - [ ] Provider bootstrap
  - [ ] TTL
  - [ ] Annotations, like `-m "more instances"`
  - [ ] Syntax for non-master branches as origin
  - [ ] Work on some more provisioner integrations
