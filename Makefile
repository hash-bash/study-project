# Define variables for paths and dependencies
PYTHON_SCRIPT = MergeDataFiles/merge_data_files.py
COMBINED_METADATA = MergeDataFiles/combined_metadata.json
PUBLIC_DIR = StaticSiteGeneration/public
STATIC_SITE_DIR = StaticSiteGeneration
RSE_CONTENT_DIR = MergeDataFiles/content
REPO_URL = https://github.com/research-software-ecosystem/content.git

# Install Python, Node.js, and dependencies
install-all:
	@command -v python3 >/dev/null 2>&1 || { echo "Python3 not found, installing..."; sudo apt-get install -y python3; }
	@command -v pip3 >/dev/null 2>&1 || { echo "pip not found, installing..."; sudo apt-get install -y python3-pip; }
	@command -v venv >/dev/null 2>&1 || { echo "venv not found, installing..."; sudo apt-get install -y python3-venv; }
	@command -v node >/dev/null 2>&1 || { echo "Node.js not found, installing..."; sudo apt-get install -y nodejs; }

	@if [ ! -d "venv" ]; then \
		echo "Creating virtual environment..."; \
		python3 -m venv venv; \
	fi

	. venv/bin/activate && python3 -m pip install -r MergeDataFiles/requirements.txt

	export NUXT_TELEMETRY_DISABLED=1
	cd $(STATIC_SITE_DIR) && npm install

# Clone or update the RSE content repository
update-content:
	if [ -d "$(RSE_CONTENT_DIR)" ]; then \
		if [ -d "$(RSE_CONTENT_DIR)/.git" ]; then \
			cd $(RSE_CONTENT_DIR) && git remote update && git branch --set-upstream-to=origin/master master && \
			CHANGES=$(git pull | grep -c "Already up to date.") && \
			if [ $$CHANGES -eq 0 ]; then \
				echo "Updates found, running Python script..."; \
				make run-python; \
			else \
				echo "No updates, skipping Python script."; \
			fi; \
		else \
			echo "$(RSE_CONTENT_DIR) is not a valid Git repository. Initializing it now..."; \
			cd $(RSE_CONTENT_DIR) && git init && git remote add origin $(REPO_URL) && git pull && \
			echo "Repository cloned, running Python script..." && \
			make run-python; \
		fi; \
	else \
		echo "Cloning repository..."; \
		git clone $(REPO_URL) $(RSE_CONTENT_DIR) && \
		echo "Repository cloned, running Python script..." && \
		make run-python; \
	fi

# Run the Python script to generate combined metadata
run-python: update-content
	python3 $(PYTHON_SCRIPT)

# Copy the generated metadata to the static site directory
copy-metadata:
	cp $(COMBINED_METADATA) $(PUBLIC_DIR)

# Generate the static site
generate-site:
	cd $(STATIC_SITE_DIR) && npm run generate

# Push combined_metadata.json to a special branch
push-metadata:
	git checkout -B combined_metadata
	git add $(COMBINED_METADATA)
	git commit -m "Update combined_metadata.json"
	git push origin combined_metadata

# Full workflow
run-full-workflow: install-all run-python copy-metadata generate-site
