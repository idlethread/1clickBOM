wildc_recursive=$(foreach d,$(wildcard $1*),$(call wildc_recursive,$d/,$2)\
			   	$(filter $(subst *,%,$2),$d))

VERSION = 0.1.4.1
PACKAGE_NAME = 1clickBOM-$(VERSION)

CHROME_COFFEE_DIR  = src/chrome/coffee
COMMON_COFFEE_DIR  = src/common/coffee
FIREFOX_COFFEE_DIR = src/firefox/coffee

CHROME_COFFEE_FILES  = $(call wildc_recursive, $(CHROME_COFFEE_DIR), *.coffee)
COMMON_COFFEE_FILES  = $(call wildc_recursive, $(COMMON_COFFEE_DIR), *.coffee)
FIREFOX_COFFEE_FILES = $(call wildc_recursive, $(FIREFOX_COFFEE_DIR), *.coffee)

COMMON_COFFEE_CHROME_TARGET_FILES = $(patsubst src/common/coffee/%.coffee, \
								   	build/chrome/js/%.js, $(COMMON_COFFEE_FILES))
CHROME_COFFEE_TARGET_FILES = build/chrome/js/background.js build/chrome/js/popup.js
COMMON_COFFEE_FIREFOX_TARGET_FILES = $(patsubst src/common/coffee/%.coffee, \
									 build/firefox/data/js/%.js, $(COMMON_COFFEE_FILES))
FIREFOX_COFFEE_TARGET_FILES = $(patsubst src/firefox/coffee/%.coffee, \
							  build/firefox/data/js/%.js, $(FIREFOX_COFFEE_FILES)) \
							  $(COMMON_COFFEE_FIREFOX_TARGET_FILES)

CHROME_HTML_FILES  = $(wildcard src/chrome/html/*)
COMMON_HTML_FILES  = $(wildcard src/common/html/*)
FIREFOX_HTML_FILES = $(wildcard src/firefox/html/*)

CHROME_LIBS_FILES  = $(wildcard src/chrome/libs/*)
COMMON_LIBS_FILES  = $(wildcard src/common/libs/*)
FIREFOX_LIBS_FILES = $(wildcard src/firefox/libs/*)

CHROME_IMAGE_FILES  = $(wildcard src/chrome/images/*)
COMMON_IMAGE_FILES  = $(wildcard src/common/images/*)
FIREFOX_IMAGE_FILES = $(wildcard src/firefox/images/*)

CHROME_DATA_FILES  = $(wildcard src/chrome/data/*)
COMMON_DATA_FILES  = $(wildcard src/common/data/*)
FIREFOX_DATA_FILES = $(wildcard src/firefox/data/*)


SUB_DIRS = target/html target/images target/libs target/data target/js
CHROME_DIRS  = build/chrome/.dirstamp \
			   $(patsubst target/%,build/chrome/%/.dirstamp, $(SUB_DIRS))
FIREFOX_DIRS = build/firefox/.dirstamp build/firefox/data/.dirstamp \
			   $(patsubst target/%,build/firefox/data/%/.dirstamp, $(SUB_DIRS)) build/

CHROME_TEMP_SRC_FILES = $(CHROME_COFFEE_FILES) $(COMMON_COFFEE_FILES) \
					   	$(COMMON_LIBS_FILES) $(CHROME_LIBS_FILES)

CHROME_TEMP_TARGET_FILES = $(addprefix .temp/, $(notdir $(CHROME_TEMP_SRC_FILES)))

all: dirs coffee images html libs data build/chrome/manifest.json \
   	 build/firefox/package.json

dirs: build/.dirstamp $(CHROME_DIRS) $(FIREFOX_DIRS)
coffee: $(CHROME_COFFEE_TARGET_FILES) $(FIREFOX_COFFEE_TARGET_FILES)
html: chrome_html firefox_html
libs: chrome_libs firefox_libs
images: chrome_images firefox_images
data: chrome_data firefox_data

build/chrome/manifest.json: src/chrome/manifest.json
	sed 's/@version/"$(VERSION)"/' $< > $@

build/firefox/package.json: src/firefox/package.json
	sed 's/@version/"$(VERSION)"/' $< > $@

.temp/.dirstamp:
	mkdir $(dir $@)
	@touch $@

.temp/%: src/chrome/coffee/%
	cp $< $@

.temp/%: src/common/coffee/tests/%
	cp $< $@

.temp/%: src/common/coffee/%
	cp $< $@

.temp/%: src/common/libs/%
	cp $< $@

build/chrome/js/background.js: .temp/.dirstamp $(CHROME_TEMP_TARGET_FILES)
	browserify --debug --transform coffeeify --extension=".coffee" \
		.temp/background.coffee -o $@

build/chrome/js/popup.js: $(CHROME_TEMP_TARGET_FILES)
	browserify --debug --transform coffeeify --extension=".coffee" \
		.temp/popup.coffee -o $@

build/firefox/data/js/%.js: $(FIREFOX_COFFEE_FILES) $(COMMON_COFFEE_FILES)
	coffee -m -c -o build/firefox/data/js/ $(FIREFOX_COFFEE_DIR) $(COMMON_COFFEE_DIR)

chrome_html: dirs $(patsubst src/common/%, build/chrome/%, $(COMMON_HTML_FILES)) \
   			$(patsubst src/%, build/%, $(CHROME_HTML_FILES))
firefox_html: dirs $(patsubst src/common/%, build/firefox/data/%,\
   	$(COMMON_HTML_FILES)) $(patsubst src/%, build/%, $(FIREFOX_HTML_FILES))

chrome_libs: dirs $(patsubst src/common/%, build/chrome/%, $(COMMON_LIBS_FILES)) \
   	$(patsubst src/%, build/%, $(CHROME_LIBS_FILES))
firefox_libs: dirs $(patsubst src/common/%, build/firefox/data/%, \
	$(COMMON_LIBS_FILES)) $(patsubst src/%, build/%, $(FIREFOX_LIBS_FILES))

chrome_images: dirs $(patsubst src/common/%, build/chrome/%, \
	$(COMMON_IMAGE_FILES)) $(patsubst src/%, build/%, $(CHROME_IMAGE_FILES))
firefox_images: dirs $(patsubst src/common/%, build/firefox/data/%, \
	$(COMMON_IMAGE_FILES)) $(patsubst src/%, build/%, $(FIREFOX_IMAGE_FILES))

chrome_data: dirs $(patsubst src/common/%, build/chrome/%, $(COMMON_DATA_FILES)) \
	$(patsubst src/%, build/%, $(CHROME_DATA_FILES))
firefox_data: dirs $(patsubst src/common/%, build/firefox/data/%, \
	$(COMMON_DATA_FILES)) $(patsubst src/%, build/%, $(FIREFOX_DATA_FILES))

watch:
	@while true; do make | grep -v "^make\[1\]:"; sleep 1; done

CHROME_PACKAGE_NAME = $(PACKAGE_NAME)-chrome

package_chrome: all
	cp -r build/chrome $(CHROME_PACKAGE_NAME)
	rm -f $(patsubst build/chrome/%,$(CHROME_PACKAGE_NAME)/%,$(CHROME_DIRS))
	zip -r $(CHROME_PACKAGE_NAME).zip $(CHROME_PACKAGE_NAME)/
	rm -rf $(CHROME_PACKAGE_NAME)

tmp.xpi: all
	cfx --pkgdir=build/firefox --output-file=/tmp/tmp.xpi xpi

load-firefox: tmp.xpi
	wget --post-file=/tmp/tmp.xpi "http://localhost:8888" || return 0

%/.dirstamp:
	mkdir $*
	@touch $@

build/chrome/%: src/chrome/%
	cp $< $@

build/chrome/%: src/common/%
	cp $< $@

build/firefox/data/%: src/firefox/%
	cp $< $@

build/firefox/data/%: src/common/%
	cp $< $@

clean:
	rm -rf .temp build

.PHONY: all dirs chrome_dirs firefox_dirs coffee clean watch package_chrome
