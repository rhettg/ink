# Terraform Builder

This is pretty simple for now, but does *actually* work.

The idea is to just turn around and call Terraform for pretty much all our
operations.

All the commands have `refresh=false` set meaning it's not going to try to
reconcile with what it finds in EC2. Local state is king. This is a bit of a
terraform workflow experiment that makes sense to me in theory anyway.
