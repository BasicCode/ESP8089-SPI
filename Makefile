MODNAME = esp8089-spi

#Shouldn't fail when not having dkms.conf in directory
#(usually when installing a built package on other system)
-include dkms.conf
PACKAGE_NAME := $(patsubst "%",%,$(PACKAGE_NAME))
PACKAGE_VERSION := $(patsubst "%",%,$(PACKAGE_VERSION))
DKMS_PATH := /usr/src/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/

#EXTRA_CFLAGS += -DDEBUG -DSIP_DEBUG -DDEBUG_FS

EXTRA_CFLAGS += -DFAST_TX_STATUS -DRX_SENDUP_SYNC

EXTRA_CFLAGS += -DKERNEL_IV_WAR -DSIF_DSR_WAR 

EXTRA_CFLAGS += -DHAS_INIT_DATA

EXTRA_CFLAGS += -DP2P_CONCURRENT 

EXTRA_CFLAGS += -DHAS_FW

EXTRA_CFLAGS += -DESP_ACK_INTERRUPT

EXTRA_CFLAGS += -DESP_USE_SPI

# EXTRA_CFLAGS += -DREGISTER_SPI_BOARD_INFO

ifdef ANDROID
EXTRA_CFLAGS += -DANDROID
endif

ifdef P2P_CONCURRENT
EXTRA_CFLAGS += -DP2P_CONCURRENT
endif

ifdef TEST_MODE
EXTRA_CFLAGS += -DTEST_MODE
endif

OBJS = esp_debug.o sdio_sif_esp.o spi_sif_esp.o esp_io.o \
    esp_file.o esp_main.o esp_sip.o esp_ext.o esp_ctrl.o \
    esp_mac80211.o esp_debug.o esp_utils.o esp_pm.o testmode.o

all: config_check modules

MODULE := $(MODNAME).ko
obj-m := $(MODNAME).o

$(MODNAME)-objs := $(OBJS)

config_check:
	@if [ -z "$(CONFIG_WIRELESS_EXT)$(CONFIG_NET_RADIO)" ]; then \
		echo; echo; \
		echo "*** WARNING: This kernel lacks wireless extensions."; \
		echo "Wireless drivers will not work properly."; \
		echo; echo; \
	fi

# Taken from here:
# http://www.xkyle.com/building-linux-packages-for-kernel-drivers/

dkms:
	$(MAKE) config_check
	echo $(DKMS_PATH)
	echo "$(KVERS_UNAME)"
	mkdir -p $(DKMS_PATH)
	cp -r . $(DKMS_PATH)
	-rm -rf $(DKMS_PATH)/.git
	-rm $(DKMS_PATH)/.gitignore
	-rm $(DKMS_PATH)/*deb
	dkms add -m $(PACKAGE_NAME) -v $(PACKAGE_VERSION)
	dkms build -m $(PACKAGE_NAME) -v $(PACKAGE_VERSION)

dkmsdeb: dkms
	dkms mkdsc -m $(PACKAGE_NAME) -v $(PACKAGE_VERSION) --source-only
	dkms mkdeb -m $(PACKAGE_NAME) -v $(PACKAGE_VERSION) --source-only 
	cp /var/lib/dkms/$(PACKAGE_NAME)/$(PACKAGE_VERSION)/deb/*.deb .

cleandkms:
	-dkms uninstall $(PACKAGE_NAME)/$(PACKAGE_VERSION)
	-dkms remove $(PACKAGE_NAME)/$(PACKAGE_VERSION) --all
	-rm -rf /var/lib/dkms/$(PACKAGE_NAME)/$(PACKAGE_VERSION) $(DKMS_PATH)

modules:
	$(MAKE) -C $(KBUILD) M=$(SRC_DIR)

$(MODULE):
	$(MAKE) modules

clean:
	rm -f *.o *.ko .*.cmd *.mod.c *.symvers modules.order
	rm -rf .tmp_versions

install: config_check $(MODULE)
	@/sbin/modinfo $(MODULE) | grep -q "^vermagic: *$(KVERS) " || \
		{ echo "$(MODULE)" is not for Linux $(KVERS); exit 1; }
	mkdir -p -m 755 $(DESTDIR)$(INST_DIR)
	install -m 0644 $(MODULE) $(DESTDIR)$(INST_DIR)
ifndef DESTDIR
	-/sbin/depmod -a $(KVERS)
endif

uninstall:
	rm -f $(DESTDIR)$(INST_DIR)/$(MODULE)
ifndef DESTDIR
	-/sbin/depmod -a $(KVERS)
endif

reinstall:
	rm -f $(DESTDIR)$(INST_DIR)/$(MODULE)
ifndef DESTDIR
	-/sbin/depmod -a $(KVERS)
endif
	rm -f *.o *.ko .*.cmd *.mod.c *.symvers modules.order
	rm -rf .tmp_versions
	mkdir -p -m 755 $(DESTDIR)$(INST_DIR); $(MAKE) $(MODULE)
	install -m 0644 $(MODULE) $(DESTDIR)$(INST_DIR)
ifndef DESTDIR
	-/sbin/depmod -a $(KVERS)
endif

.PHONY: all modules clean install config_check reinstall uninstall
