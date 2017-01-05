# Ink

Ink is a workflow for using [Terraform](https://www.terraform.io) with git.

## Why use Ink

Terraform is, out-of-the-box, a great tool for managing infrastructure using
code. However, finding a workflow for collaboration can be a challenge.

You should already be tracking your terraform code and configs in revision
control like git, so why not also use it to manage the workflow and
collaboration?

## How Ink Works

Any state generated by Terraform or by your commands will be tracked inside a
git repository alongside your infrastructure code.  The revision history of the
repository then truly becomes the revision history of your infrastructure.

For example, imagine you have a repository with terraform configuration
in it. You need to tell ink to manage this repository:

    $ ink add git@github.com:github/octobatman.git
    Added octobatman

To use the terraform configurations provided in the repo:

    $ ink apply octobatman
    Apply success!
    https://github.com/github/octobatman/commits/72e21

This command will:

  1. Pull any changes to the `master` branch from origin (github.com)
  1. Execute `terraform apply`
  1. Commit any changes and push back to origin.

The updated state file and any output from the command will be safely tracked in git.

To find the resources created by terraform, you can view your configured "outputs".

    $ ink output octobatman
    server_ip: 53.123.34.100

The awesome part about having your infrastrucuture automated with a tool like
terraform is you can easily blow it away and create it again.

    $ ink destroy octobatman

## Making Changes

Ink supports using feature branches to develop your infrastructure changes.
As an example, imagine you were changing the name of a security group in your
terraform configs. You would create a feature branch:

    $ git checkout -b sg-fix
    $ vi main.tf
    $ git commit -a -m "fixed security group"
    $ git push -u origin sg-fix

To fully understand the impact of your changes, you'll want to generate a plan.

    $ ink plan octobatman sg-fix
    Plan success!
    https://github.com/github/octobatman/commits/48215ab

This will auto-create a new branch based off `master` and merge in your
changes.  Ink then runs `terraform plan`. The outputted revision is useful so
you can later ensure you are applying the same changes.

If you're satisifed with these changes, you can then apply them:

    $ ink apply octobatman 48215ab

This will use the same plan generated above and merge your changes into the stack.

## Multiple Environments

It may be useful to use the same terraform code to generate multiple
environments. You might want to have similiar configurations for `production`
and `staging`, and maybe even one-off experiments like `lab-abcd`.

Ink can power this workflow by supporting multiple environments through branching.

    $ ink add git@github.com:github/octobatman.git ink_id=production
    Added octobatman-production

If you check your repo's origin, you'll see an important addition: A new branch
named `ink-octobatman-production`.

Using multiple environments to safely develop infrastructure changes can be
particularly valuable. Using the above security-group change example, with
multiple environments you have some more options.

To test your change in an alternate environment first:

    $ ink add github/octobatman ink_id=sg-fix-test
    Added octobatman-sg-fix-test

    $ ink apply octobatman-sg-fix-test
    Apply success!

    $ ink plan octobatman-sg-fix-test sg-fix
    Plan success!
    https://github.com/github/octobatman/commits/48215ab

    $ ink apply octobatman-sg-fix-test 48215ab
    Apply success!

Everything looks good, you can now merge the same change into production

    $ ink plan octobatman-production sg-fix
    Plan success!
    https://github.com/github/octobatman/commits/6831de
    $ ink apply octobatman-production 6831de
    Apply success!

*DON'T FORGET* you still need to merge your change into `master`.

## Environment Configuration

Multiple environments will often need some configuration like user-defined
variables to vary between environments.  When adding a repo for multiple
environments, you can include additional values to be passed along as terraform
vars. For example:

    $ ink add git@github.com:github/octobatman.git id=staging vpc_id=vpc-abc1234
    Added octobatman-staging

You can then access variables inside your terraform configs as they are passed
to terraform as environment variables like `TF_VAR_vpc_id`.

There are also some useful built-in variables that can be used by your configurations:

  * `ink_id` - The uniquely generated portion of the name, for example `staging` in the above examples.
  * `ink_name` - The full name of your ink environment, like `octobatman-staging` in the above examples.

## Command Reference

While ink is a wrapper around terraform, not all commands are implemented. They
don't always make sense in a remote context.

  * `ink add <git repository>` - Clone a repository and configure a new ink branch.
  * `ink refresh <name> []` - Run `terraform refresh`
  * `ink plan <name> [branch]` - Generate a plan file for any changes in the branch.
  * `ink apply <name> [rev]` - Apply changes in the branch, using a plan file if available.
  * `ink output <name>` - Run `terraform output`
  * `ink list` - Show available ink projects
  * `ink key` - Display SSH public key to authorize ink for use in your repo.

## Scripts and Extensions

Ink supports user-defined scripts, similiar to the [Scripts to Rule Them All](https://github.com/github/scripts-to-rule-them-all) Concept.

  * `script/setup` - If it exists and is executable, ink will automatically execute it during `add`
  * `script/update` - If exists and is executable, ink will automatically execute it before anything mutable action.

## Installation

You'll likely want to run ink on some coordinator host in your production
network (meaning, not locally).

All you need is a workspace for ink to clone git repositories and some
environment variables needed for your scripts to do the work they need.

Create a space like `/var/lib/ink`, and make sure you always run ink inside
this path.

## Development

We Test.
Build Status: [![Circle CI](https://circleci.com/gh/rhettg/ink.svg?style=svg)](https://circleci.com/gh/rhettg/ink)

### Local Installation

Ok fine, you can run this on your laptop in your development environment if you want.

The difference is going to be you are going to manage the clone of the repo
yourself. Ink is also going to ignore if the repo has a remote at all.

Run ink from inside the repository starting with:

    $ ink add .

### TODO

  - [ ] auto-cleanup remote plan branches
  - [ ] Lockfile for server mode
  - [ ] TTL
