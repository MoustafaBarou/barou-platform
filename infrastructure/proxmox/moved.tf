moved {
  from = proxmox_virtual_environment_vm.ubuntu_tf_01
  to   = module.ubuntu_vm["ubuntu-tf-01"].proxmox_virtual_environment_vm.this
}
