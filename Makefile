# clear default rules
MAKEFLAGS += --no-builtin-rules

NAME ?= javan-rhino
TMPDIR ?= $(CURDIR)/tmp
BUILDDIR ?= $(CURDIR)/charm-dist

$(TMPDIR) $(BUILDDIR):
	mkdir -p $@


# charm stuff

# defaults
CHARM_SERIES ?= xenial
CHARM_SRC ?= $(CURDIR)/charm
JUJU_REPOSITORY = $(BUILDDIR)
CHARMDIR = $(BUILDDIR)/$(CHARM_SERIES)/$(NAME)
CHARMREPODIR = $(BUILDDIR)/build
GIT_CHARMREPODIR = $(CHARMREPODIR)/.git
PAYLOAD = $(CHARMDIR)/files/$(NAME).tgz
CHARM = $(CHARMDIR)/.done
LAYER_PATH = $(TMPDIR)/layer
INTERFACE_PATH = $(TMPDIR)/interface
CHARM_WHEELDIR = $(TMPDIR)/wheels
CHARM_DEPS = $(LAYER_PATH)/.done $(INTERFACE_PATH)/.done
EXTRA_CHARM_BUILD_ARGS ?=
DEPLOY_ENV ?= devel
DISTDIR = dist
DIST = $(DISTDIR)/.done
GIT_HEAD_HASH = $(shell git rev-parse HEAD)

export INTERFACE_PATH
export LAYER_PATH
export JUJU_REPOSITORY


$(CHARM_DEPS): $(TMPDIR) $(CHARM_SRC)/charm-deps
	cd $(TMPDIR) && codetree $(CHARM_SRC)/charm-deps
	touch $(CHARM_DEPS)

$(CHARM): $(CHARM_SRC) $(CHARM_SRC)/* $(CHARM_PREQS) $(CHARM_DEPS) | $(BUILDDIR)
	rm -rf $(CHARMDIR)
	PIP_NO_INDEX=true PIP_FIND_LINKS=$(CHARM_WHEELDIR) charm build -o $(BUILDDIR) -s $(CHARM_SERIES) -n $(NAME) $(EXTRA_CHARM_BUILD_ARGS) ./charm
	touch $@

version-info:
	echo '$(GIT_HEAD_HASH)' > $@.txt

clean:
	rm -rf $(BUILDDIR)
	rm -rf $(TMPDIR)
	rm -f $(PAYLOAD)
	rm -rf dist
	rm -rf node_modules

.DELETE_ON_ERROR: $(DISTDIR)
.INTERMEDIATE: $(DISTDIR)
$(DIST):
	rm -rf $(DISTDIR)
	mkdir -p $(DISTDIR)
	npm install
	npm run build
	touch $@

$(PAYLOAD): $(CHARM) $(DIST) version-info build-tar-exclude.txt $(SRC) $(SRC)/* $(SRC_PREQS)
	tar cz --exclude-vcs --exclude-from build-tar-exclude.txt -f $(PAYLOAD) .

## build the charm and payload
build: $(PAYLOAD)

deploy: build
	juju deploy local:$(CHARM_SERIES)/$(NAME)
	juju deploy memcached
	juju add-relation $(NAME) memcached
	juju set $(NAME) session_secret='its a secret' \
		environment=$(DEPLOY_ENV) \
		memcache_session_secret='its another secret'


# Targets for building, committing and pushing charm builds to a git repo

check-git-build-vars:
ifndef BUILDREPO
	$(error BUILDREPO is required)
endif

$(GIT_CHARMREPODIR): check-git-build-vars
	rm -rf $(BUILDDIR)
	git clone --branch $(BUILDBRANCH) $(BUILDREPO) $(CHARMREPODIR)

git-build: BUILDBRANCH ?= staging
git-build: EXTRA_CHARM_BUILD_ARGS = --force
git-build: RSYNC_EXCLUDES = --exclude=.git --exclude=.gitignore --exclude=.done --exclude=.build.manifest
git-build: $(GIT_CHARMREPODIR) build
	rsync -a -m --ignore-times --delete $(RSYNC_EXCLUDES) $(CHARMDIR) $(CHARMREPODIR)
	cd $(CHARMREPODIR) && GIT_DIR=$(GIT_CHARMREPODIR) git add .
	cd $(CHARMREPODIR) && GIT_DIR=$(GIT_CHARMREPODIR) git commit -am "Build of $(NAME) from $(GIT_HEAD_HASH)"
	cd $(CHARMREPODIR) && GIT_DIR=$(GIT_CHARMREPODIR) git push origin $(BUILDBRANCH)

.PHONY: version-info build deploy clean