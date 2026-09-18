# F4PGA build for the Digilent Zybo Z7-10 (xc7z010clg400-1).
#
# This follows the maintained F4PGA examples' Zybo flow.  The f4pga build
# runner in the z010 image does not provide a Zynq-7010 platform definition;
# its supported Zybo route is the symbiflow_* wrapper sequence below.

.DEFAULT_GOAL := bitstream

CONTAINER_ENGINE ?= docker
F4PGA_IMAGE ?= ghcr.io/hdl/conda/f4pga/xc7/z010:latest

BUILD_DIR := build/zybo-z7-10
BITSTREAM := $(BUILD_DIR)/top.bit
TOP := top
PART := xc7z010clg400-1
FAMILY := zynq7
VPR_DEVICE := xc7z010_test
XDC := Zybo-Z7-10.xdc
SOURCES := top.v uart_tx.v hc_sr04_controller.v $(XDC)
WORKSPACE := $(abspath .)

.PHONY: all bitstream clean help

all: bitstream

bitstream: $(BITSTREAM)

$(BITSTREAM): $(SOURCES) Makefile
	mkdir -p $(BUILD_DIR)
	$(CONTAINER_ENGINE) run --rm \
		-v "$(WORKSPACE):/wrk" \
		-w "/wrk/$(BUILD_DIR)" \
		$(F4PGA_IMAGE) \
		bash -lc 'source /usr/local/etc/profile.d/conda.sh && \
			conda activate xc7 && \
			symbiflow_synth -t $(TOP) -v /wrk/top.v /wrk/uart_tx.v /wrk/hc_sr04_controller.v -d $(FAMILY) -p $(PART) -x /wrk/$(XDC) && \
			symbiflow_pack -e $(TOP).eblif -d $(VPR_DEVICE) -s $(TOP).sdc && \
			symbiflow_place -e $(TOP).eblif -d $(VPR_DEVICE) -n $(TOP).net -P $(PART) -s $(TOP).sdc && \
			symbiflow_route -e $(TOP).eblif -d $(VPR_DEVICE) -s $(TOP).sdc && \
			symbiflow_write_fasm -e $(TOP).eblif -d $(VPR_DEVICE) && \
			symbiflow_write_bitstream -d $(FAMILY) -f $(TOP).fasm -p $(PART) -b $(TOP).bit'

clean:
	rm -rf $(BUILD_DIR)

help:
	@printf '%s\n' \
		'Usage:' \
		'  make bitstream  Generate build/zybo-z7-10/top.bit with F4PGA.' \
		'  make clean      Remove F4PGA build products.' \
		'' \
		'Overrides: CONTAINER_ENGINE=podman F4PGA_IMAGE=<image>'
