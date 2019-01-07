# VoIRC

The Voice over IRC client.

The code is terrible. Sorry. It might get better. 

## Requirements

* Nim (tested with 0.19.2)
* GNU make
* Unicode-compliant ncurses
* codec2 0.8.1 ([source](https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/codec2/0.8.1-2/codec2_0.8.1.orig.tar.xz))
* libsoundio 1.1.0 ([source](https://github.com/andrewrk/libsoundio/archive/1.1.0.tar.gz))
* The following Nim packages (install with "nimble install"):
    * irc
    * ncurses
    * soundio

## Installation

1. Run "make".
2. Run "./voirc [IRC server](:port) [nickname] '[#channel]'.
3. Press F12 to toggle voice transmission!
