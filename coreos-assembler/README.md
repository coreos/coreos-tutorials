# CoreOS Assembler Tutorial

## Background

To develop, build, and debug CoreOS we use a tool called [`coreos-assembler`](https://github.com/coreos/coreos-assembler) also known as `cosa`. The software is run as a container and can be pulled from the `quay.io` container registry.

## Setup

A good way to run `cosa` is by using a bash function that wraps a `podman run` or `docker run` command. There are more complex versions of this function in [the docs](https://github.com/coreos/coreos-assembler/blob/main/docs/building-fcos.md#define-a-bash-alias-to-run-cosa), but for the purposes of this lab we can use something a little more basic:

```
cosa() {
   podman run --rm -ti --security-opt=label=disable --privileged           \
              --uidmap=1000:0:1 --uidmap=0:1:1000 --uidmap=1001:1001:64536 \
              -v=${PWD}:/srv/ --device=/dev/kvm --device=/dev/fuse         \
              --tmpfs=/tmp --name=cosa                                     \
              quay.io/coreos-assembler/coreos-assembler:latest "$@"
   rc=$?; return $rc
}
```

Now that we have the bash function defined let's create a space for our tutorial files to live and
initialize a directory structure:

```
mkdir tutorial
cd tutorial
cosa init --branch=cosa-tutorial-fedora-coreos-config \
    --commit=c7e35d0e66792560f55e1c299c25fa182bbb3171 \
    https://github.com/coreos/coreos-tutorials.git
```

NOTE: The first run of `cosa` will take some extra time on startup due to initialization.

## Tutorial

In the `cosa init` command above we set up `cosa` to initialize a "config repo" from `https://github.com/dustymabe/fedora-coreos-config.git` at a specific commit. The config repo is what defines what will go into the CoreOS image(s) that are going to be built. Since the config repo is backed by `git` you can checkout different commits in the history and build an image from the source at that time.

Now that we have the working directory initialized let's go ahead and `fetch` and `build`:

```
cosa fetch && cosa build
```

The `cosa fetch` command grabbed RPMs that are necessary to build and the `cosa build` command is a combination of `cosa build ostree` and `cosa buildextend-qemu`. `cosa build` is a convenience since usually local developers want to run a qemu qcow in order to test/debug/hack. You should have seen:

```
Successfully generated: fedora-coreos-38.20230731.dev.0-qemu.x86_64.qcow2
```

In the `builds/` directory we can now see:

```
$ ls builds
38.20230731.dev.0  builds.json  latest
$ readlink builds/latest
38.20230731.dev.0
```

Where `builds.json` keeps track of the builds that have been built and `latest` is a symlink to the most recent build.

When a `cosa` command is run it usually operates on the latest build (as found via the `latest` symlink). For example we can now `run` a CoreOS instance from the qcow we just built:

```
cosa run
```

This command will boot the machine and log you in via SSH automatically. The machine will be destroyed after exiting the SSH session:

```
[core@cosa-devsh ~]$ exit
```

Though sometimes you might be debugging something in early boot, in which case you can tell `cosa` to connect to the serial console of the instance rather than via SSH:

```
cosa run --devshell-console
```

NOTE: If the console output seems stuck press `CTRL-c` and `<ENTER>` a few times to get the shell.

You can exit from this session (and thus terminate the machine) via `CTRL-a` + `x`.


Next, let's run a test. There are a lot of automated tests that are
defined that can be run against a CoreOS build. Let's view them now:

```
cosa kola list
```

Let's pick out a simple one to run. The `ext.config.files.license` test just verifies that a `LICENSE` file was added for the `fedora-coreos-config` contents into the build image. Inspect the source for the test via:

```
cat src/config/tests/kola/files/license
```

We can run the test with `cosa kola run` via: 

```
cosa kola run ext.config.files.license
```

Next let's change the test contents to force the test to fail by doing a directory check instead of a regular file check:

```
sed -i 's/test -f/test -d/' src/config/tests/kola/files/license
git -C src/config diff
cosa kola run ext.config.files.license
```

Since the `/usr/share/licenses/fedora-coreos-config/LICENSE` file is a regular file the test now fails. Modifying tests or adding new tests is as easy as dropping new files  (scripts) into the `tests/kola` directory.

Now let's restore the test and also "pull" newer content in the git repo; this is simulating moving forward in time (i.e. new software/content is availabe for Fedora CoreOS).

```
git -C src/config/ checkout tests/kola/files/license
git -C src/config pull --deepen=5
```

We can now fetch new required RPMs and do a new build. This time we limit the build to just the OSTree.

```
cosa fetch && cosa build ostree
```

Once the build is complete we see in the output the updated package set:

```
Upgraded:
  fwupd 1.9.2-1.fc38 -> 1.9.3-2.fc38
  libsmbclient 2:4.18.4-0.fc38 -> 2:4.18.4-1.fc38
  libwbclient 2:4.18.4-0.fc38 -> 2:4.18.4-1.fc38
  samba-client-libs 2:4.18.4-0.fc38 -> 2:4.18.4-1.fc38
  samba-common 2:4.18.4-0.fc38 -> 2:4.18.4-1.fc38
  samba-common-libs 2:4.18.4-0.fc38 -> 2:4.18.4-1.fc38
  selinux-policy 38.20-1.fc38 -> 38.21-1.fc38
  selinux-policy-targeted 38.20-1.fc38 -> 38.21-1.fc38
```

We can also see a new build in the builds directory and the `latest` symlink has been updated:

```
$ ls builds/
38.20230731.dev.0  38.20230731.dev.1  builds.json  latest
$ readlink builds/latest
38.20230731.dev.1
```

But there is no qcow available yet for the `38.20230729.dev.1` build:

```
$ ls builds/*/x86_64/*qcow2
builds/38.20230731.dev.0/x86_64/fedora-coreos-38.20230731.dev.0-qemu.x86_64.qcow2
```

To build the qemu qcow image for the new build just run:

```
cosa buildextend-qemu
```

NOTE: You can build any Fedora CoreOS artifact this way. For example `cosa buildextend-aws` or `cosa buildextend-gcp`. Feel free to try it out!

Now run the test same test again to see if it still passes:

```
cosa kola run ext.config.files.license
```

It appears this time there is a legitimate test failure:

```
=== RUN   ext.config.files.license
2023-07-31T19:33:48Z platform: some systemd units failed: chronyd.service
--- FAIL: ext.config.files.license (22.62s)
        harness.go:1741: mach.Start() failed: machine "ba901b08-7efb-4a95-bc1c-97494961221b" failed basic checks: detected failed or stuck systemd units
```

The logs from the test are in `tmp/kola` for inspection:

```
$ ls tmp/kola/ext.config.files.license/*/
console.txt  ignition.json  journal-raw.txt.gz  journal.txt
```

But we can just hop right into a VM to do some debugging with:

```
cosa run
```

The prompt even shows that the with the `chronyd.service` unit failure is consistent:

```
$ cosa run
Fedora CoreOS 38.20230731.dev.1
Tracker: https://github.com/coreos/fedora-coreos-tracker
Discuss: https://discussion.fedoraproject.org/tag/coreos

Last login: Mon Jul 31 19:36:23 2023
[systemd]
Failed Units: 1
  chronyd.service
[core@cosa-devsh ~]$
```

Now that we have a shell on the system we can investigate further:

```
systemctl status chronyd.service
journalctl | grep -B 5 -A 5 'Could not open /etc/chrony.conf'
```

There is a message in the journal that might be a clue:

```
Jul 31 19:36:22 localhost audit[1524]: AVC avc:  denied  { read } for  pid=1524 comm="chronyd" name="chrony.conf" dev="vda4" ino=934849 scontext=system_u:system_r:chronyd_t:s0 tcontext=system_u:object_r:shadow_t:s0 tclass=file permissive=0
```

Using the information from earlier we know that the `fwupd` `samba` and `selinux-policy` packages were changed since the last build that passed all tests. Since this failure is an SELinux denial it would be logical to investigate there first.

We can stop that old system:

```
[core@cosa-devsh ~]$ exit
```

And start a new system while adding the `enforcing=0` kernel command line argument via the `--kargs` argument to `cosa run`:

```
cosa run --kargs='enforcing=0'
```

Now we can inspect the running system:

```
getenforce
systemctl status chronyd
journalctl -o cat -b 0 --grep AVC
exit
```

We were able to set a kernel argument to set SELinux to permissive in order to further investigate a problem. That was nice and convenient, but there is another way to change files for a built image that may be required for development/testing (i.e. if no simple kernel argument exists). You can override any file or RPM by manipulating content under the `overrides/` directory.

For example, let's set SELinux to permissive a different way by writing some configuration into a file in `overrides/rootfs/etc/selinux`:

```
mkdir -p overrides/rootfs/etc/selinux
echo -e 'SELINUX=permissive\nSELINUXTYPE=targeted' > overrides/rootfs/etc/selinux/config
cosa build && cosa run
```

Now we can see that the configuration was able to override the default delivered by the RPM and made it into the built image:


```
cat /etc/selinux/config
getenforce
systemctl status chronyd
journalctl -o cat -b 0 --grep AVC
exit
```

Now let's clean up that overridden file so new builds that we do won't have it:

```
rm overrides/rootfs/etc/selinux/config 
rmdir overrides/rootfs/etc/selinux overrides/rootfs/etc
```

At this point it's pretty safe to say this is an SELinux problem, most likely related to the new package update `selinux-policy 38.20-1.fc38 -> 38.21-1.fc38`. To confirm that let's *ONLY* revert the SELinux packages to the versions from the last build.

We can do that by placing those older versions into the `overrides/rpm` directory:

```
cosa shell -- bash -c "cd overrides/rpm && koji download-build selinux-policy-38.20-1.fc38"
```

Here we are running the `koji download-build` command within the COSA container (since we know `koji` CLI is installed there) to grab the RPM files for the previous `selinux-policy`.

Once these files are in that directory the `cosa build` will pick them up and use them. They take priority over any other specified version (a convenient development tool). Let's do the build:

```
cosa build
```

Observing the output go by we can see the packages from the overrides directory getting used:

```
  selinux-policy-38.20-1.fc38.noarch (coreos-assembler-local-overrides)
  selinux-policy-targeted-38.20-1.fc38.noarch (coreos-assembler-local-overrides)
```

Once the build is complete we can re-run our test to see if it passes this time:

```
cosa kola run ext.config.files.license
```

And of course it does pass! It seems almost certain the problem is related to the `selinux-policy-38.21-1.fc38` update.

If we want to go back and investigate further the broken system we can always just specify which build to operate on:

```
OLDESTBUILD=$(jq -r .builds[-1].id builds/builds.json)
echo $OLDESTBUILD
cosa run --build=$OLDESTBUILD
```

Now we are armed with enough information to open an issue or bug with the maintainers to investigate and get the issue fixed. For Fedora CoreOS we typically will pin on an older version of a package until a fix exists.

That was a good exercise, but most of the time people may report an issue in an existing Fedora CoreOS (i.e. maybe a new issue we don't have test coverage for). In that case we can just download an existing build and inspect it using `cosa` without having to build a new copy locally using:

```
cosa buildfetch --stream=stable --build=38.20230709.3.0 --artifact=qemu
cosa decompress
cosa run
```

Which shows:

```
$ cosa run
Fedora CoreOS 38.20230709.3.0
Tracker: https://github.com/coreos/fedora-coreos-tracker
Discuss: https://discussion.fedoraproject.org/tag/coreos

[core@cosa-devsh ~]$
```

## Cleanup

You can now cleanup by deleting the files and removing the tutorials directory:


```
cosa shell -- sudo rm -rf builds/ cache/ overrides/ src/ tmp/
cd ..
rmdir tutorial
```

NOTE: Because of user namespacing it's easier to delete the files from inside the `cosa` container. Deleting them from outside the container my require `sudo` access.
