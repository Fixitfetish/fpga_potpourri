\brief This file includes the DOXYGEN documentation entry page of the RAM Library.

\page RAM_LIBRARY RAM Library Overview

Introduction
============

The RAM library
* single-port and dual-port RAMs
* ROMs
* synchronous and asynchronous FIFOs

The main goal of this library is to simplify the process of moving designs between
different FPGA device types and vendors with different RAM/FIFO cell primitives.

Contents
========

| Entity Name                           |  behavioral          | UltraScale            | Description
|:--------------------------------------|:---------------------|:----------------------|:-----------------
| fifo_logic_sync                       |  ---                 | ---                   | Logic for RAM based synchronous FIFO
| fifo_async                            |  ---                 | ---                   | Asynchronous FIFO
| fifo_sync                             |  fifo_sync.behave    | ---                   | Synchronous FIFO
| ram_sdp                               | ram_sdp.behave       | ram_sdp.ultrascale    | Simple Dual Port RAM
| ram_arbiter_read                      | ---                  | ---                   | ---
| ram_arbiter_read_data_width_adapter   | ---                  | ---                   | ---
| ram_arbiter_write                     | ---                  | ---                   | ---
| ram_arbiter_write_data_width_adapter  | ---                  | ---                   | ---

TODO
====

---
MIT License : Copyright (c) 2017-2019 Fixitfetish
 - <https://opensource.org/licenses/MIT>
 - <https://en.wikipedia.org/wiki/MIT_License>
