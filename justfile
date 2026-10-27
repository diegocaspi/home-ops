mod talos
mod terraform

repo := justfile_directory()

# List available recipes
default:
    @just --list
