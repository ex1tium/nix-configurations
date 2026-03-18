{ lib, ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-path/pci-0000:00:12.7-scsi-0:0:0:0";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            label = "EFI";
            size = "2G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          swap = {
            label = "cryptswap";
            size = "12G";
            content = {
              type = "luks";
              name = "cryptswap";
              content = {
                type = "swap";
                resumeDevice = false;
              };
            };
          };

          luks = {
            label = "cryptroot";
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              content = {
                type = "btrfs";
                extraArgs = [ "-L" "nixos" "-f" ];
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = [ "subvol=@root" "compress=zstd" "noatime" ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "subvol=@home" "compress=zstd" "noatime" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "subvol=@nix" "compress=zstd" "noatime" ];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "subvol=@persist" "compress=zstd" "noatime" ];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [ "subvol=@snapshots" "compress=zstd" "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
