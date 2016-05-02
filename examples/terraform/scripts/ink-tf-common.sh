# We never want interaction
export TF_INPUT=0

terraform_get () {
  if ! output=$(terraform get -no-color); then
    echo "Failed to retrieve dependencies"
    echo "${output}"
    exit 1
  fi
}

ink_tf_init () {
  terraform_get
}

ink_tf_create () {
  if [ -f terraform.tfstate ]; then
    echo "State already exists"
    exit 1
  fi

  terraform_get

  if ! terraform apply; then
    exit 1
  fi
}

ink_tf_update () {
  terraform_get

  if ! terraform apply -refresh=false; then
    echo "Failed to apply"
    exit 1
  fi
}

ink_tf_plan () {
  terraform_get

  terraform plan -refresh=false
}

ink_tf_show () {
  if [ ! -f terraform.tfstate ]; then
    echo "Not created"
  else
    terraform output
  fi
}

ink_tf_destroy () {
  if ! terraform destroy -force -refresh=false; then
    echo "Failed to destroy"
  fi
}
