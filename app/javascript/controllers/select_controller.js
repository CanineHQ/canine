import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";
import { computePosition, flip, shift, offset } from "@floating-ui/dom";

export default class extends Controller {
  static values = {
    url: String, // URL to fetch options from
    valueField: { type: String, default: "value" }, // Field to use for value
    labelField: { type: String, default: "label" }, // Field to use for label
    submitOnChange: { type: Boolean, default: false }, // Submit form on change
    dropdownInput: { type: Boolean, default: true }, // Enable dropdown input plugin
    dropdownInputPlaceholder: { type: String, default: "Search..." }, // Custom placeholder for dropdown input (if "", it will use the default placeholder)
    clearButton: { type: Boolean, default: false }, // Show clear button when typing or option selected (onle for single select, this is never shown for multiple select)
    disableTyping: { type: Boolean, default: false }, // Disable typing
    allowNew: { type: Boolean, default: false }, // Allow new options
    scrollButtons: { type: Boolean, default: false }, // Show scroll buttons
    updateField: { type: Boolean, default: false }, // Update field with selected value
    updateFieldTarget: String, // Target to update
    updateFieldSource: { type: String, default: "name" }, // Source to update
    perPage: { type: Number, default: 60 }, // Number of options per page
    virtualScroll: { type: Boolean, default: false }, // Use virtual scroll
    optgroupColumns: { type: Boolean, default: false }, // Use optgroup columns
    responseDataField: { type: String, default: "data" }, // Field in response containing array of items (auto-detects common patterns)
    searchParam: { type: String, default: "query" }, // Search parameter name for the API
    // New flexible rendering options
    imageField: String, // Field containing image URL
    subtitleField: String, // Field to show as subtitle
    metaFields: String, // Comma-separated fields to show as metadata (e.g., "status,species")
    badgeField: String, // Field to show as a badge/tag
    renderTemplate: String, // Custom template for option rendering
    // New count display options
    showCount: { type: Boolean, default: false }, // Show count instead of individual items
    countText: { type: String, default: "selected" }, // Text to show after count
    countTextSingular: { type: String, default: "" }, // Text to show when only one item is selected (optional)
    // Tags position options
    tagsPosition: { type: String, default: "inline" }, // Position of tags: "inline" (inside input), "above", "below", or a custom container ID
    // Flag toggle options
    enableFlagToggle: { type: Boolean, default: false }, // Enable flag toggle buttons on tags
    // Internationalization options
    noMoreResultsText: { type: String, default: "No more results" }, // Text to show when there are no more results
    noSearchResultsText: { type: String, default: "No results found for" }, // Text to show when no results match the search (will be followed by the search term)
    loadingText: { type: String, default: "Loading..." }, // Text to show when loading more results
    createText: { type: String, default: "Add" }, // Text to show for the create option
  };

  connect() {
    if (this.element.tomselect) return;

    const options = this.#buildOptions();
    this.select = new TomSelect(this.element, options);

    this.#setupEventHandlers();
    this.#setupPositioning();
    this.#handleInitialValue();
    this.#preventNativeFocus();

    this.element.style.visibility = "visible";
  }

  disconnect() {
    this.#cleanup();
  }

  // Private methods

  #buildOptions() {
    const plugins = this.#getPlugins();
    const baseOptions = {
      plugins,
      maxOptions: null,
      closeAfterSelect: !this.element.multiple,
      create: this.allowNewValue,
      render: this.#getRenderConfig(),
      onChange: this.#handleChange.bind(this),
      onDropdownOpen: () => this.#updatePosition(),
    };

    if (!this.hasUrlValue) return baseOptions;

    return {
      ...baseOptions,
      preload: true,
      ...(this.virtualScrollValue ? this.#getVirtualScrollConfig() : this.#getCustomScrollConfig()),
    };
  }

  #getPlugins() {
    const plugins = [];
    const isMultiple = this.element.multiple;
    const useVirtualScroll = this.virtualScrollValue && this.hasUrlValue;

    if (useVirtualScroll) {
      plugins.push("virtual_scroll");
      if (isMultiple) plugins.push("remove_button", "checkbox_options", "no_active_items");
    } else if (isMultiple) {
      plugins.push("remove_button", "checkbox_options", "drag_drop", "no_active_items");
    }

    if (this.optgroupColumnsValue) plugins.push("optgroup_columns");
    if (this.dropdownInputValue) plugins.push("dropdown_input");

    return plugins;
  }

  #getRenderConfig() {
    const renderOption = (data, escape) => {
      if (this.renderTemplateValue) return this.#renderWithTemplate(this.renderTemplateValue, data, escape);
      if (this.hasUrlValue && this.#hasCustomFields()) return this.#renderApiOption(data, escape);
      return this.#renderStandardOption(data, escape);
    };

    const renderItem = (data, escape) => {
      if (this.hasUrlValue && this.imageFieldValue && data[this.imageFieldValue]) {
        return this.#renderImageItem(data, escape);
      }
      return this.#renderStandardItem(data, escape);
    };

    return {
      option: renderOption,
      item: renderItem,
      option_create: (data, escape) => `<div class="create">${escape(this.createTextValue)} <strong>${escape(data.input)}</strong>&hellip;</div>`,
      loading_more: () => this.#renderLoadingMore(),
      no_more_results: () =>
        `<div class="no-more-results py-2 text-center text-sm text-neutral-500 dark:text-neutral-400">${this.noMoreResultsTextValue}</div>`,
      no_results: (data, escape) => `<div class="no-results">${escape(this.noSearchResultsTextValue)} "${escape(data.input)}"</div>`,
    };
  }

  #getVirtualScrollConfig() {
    return {
      valueField: this.valueFieldValue,
      labelField: this.labelFieldValue,
      searchField: this.labelFieldValue,
      firstUrl: (query) => this.#buildApiUrl(this.urlValue, query, 1),
      load: this.#virtualScrollLoad.bind(this),
      shouldLoadMore: this.#shouldLoadMore.bind(this),
    };
  }

  #getCustomScrollConfig() {
    return {
      valueField: this.valueFieldValue,
      labelField: this.labelFieldValue,
      searchField: this.labelFieldValue,
      load: this.#customScrollLoad.bind(this),
    };
  }

  async #virtualScrollLoad(query, callback) {
    // Early return if select is destroyed
    if (!this.select) {
      callback();
      return;
    }

    const url = this.select.getUrl(query);
    const scrollState = this.#captureScrollState(url);

    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(response.statusText);

      const rawJson = await response.json();
      const json = this.#transformApiResponse(rawJson);

      // Check if select still exists before updating state
      if (this.select) {
        this.#updateVirtualScrollState(url, query, json);
        callback(json.data);

        // For pages after the first, just maintain scroll position
        if (scrollState.currentPage > 1) {
          requestAnimationFrame(() => {
            if (this.select?.dropdown_content && typeof scrollState.scrollTop === "number") {
              this.select.dropdown_content.scrollTop = scrollState.scrollTop;
            }
          });
        } else {
          requestAnimationFrame(() => {
            this.#restoreScrollState(scrollState);
            this.#handlePostLoadFocus(query, scrollState);
          });
        }
      } else {
        callback();
      }
    } catch (error) {
      console.error("Virtual scroll load error:", error);
      this.select?.setNextUrl(query, null);
      callback();
    } finally {
      this.#cleanupScrollState();
    }
  }

  async #customScrollLoad(query, callback) {
    this.#resetPagination();

    try {
      const response = await this.#fetchPage(query, 1);
      const json = this.#transformApiResponse(response);

      callback(json.data);
      this.hasMore = json.has_more;

      if (this.select?.dropdown_content) {
        this.#setupInfiniteScroll();
        setTimeout(() => this.#focusFirstOption(query), 10);
      }
    } catch (error) {
      console.error("Custom scroll load error:", error);
      callback();
      this.hasMore = false;
    }
  }

  #setupEventHandlers() {
    // Override setActiveOption for single active state and custom scrolling
    const original = this.select.setActiveOption.bind(this.select);
    this.select.setActiveOption = (option, scroll) => {
      this.#clearAllActiveStates();

      // Prevent TomSelect's default scrolling, use our custom scroll instead
      const result = original(option, false);

      // Apply our custom scroll behavior with padding
      if (option && scroll !== false) {
        this.#scrollToOption(option);
      }

      return result;
    };

    // Clear options if URL-based
    if (this.hasUrlValue) this.select.clearOptions();

    // Dropdown open handler
    this.select.on("dropdown_open", () => this.#handleDropdownOpen());

    // Setup additional features
    if (this.scrollButtonsValue && this.select.dropdown_content) this.#addScrollButtons();
    if (this.element.multiple) this.#setupScrollTracking();
    if (this.disableTypingValue) this.#setupReadonlyInput();

    // Setup count display for multi-select
    if (this.element.multiple && this.showCountValue) {
      this.#setupCountDisplay();
    }

    // Setup external tags display for multi-select
    if (this.element.multiple && this.tagsPositionValue !== "inline") {
      this.#setupExternalTags();
    }

    // Setup custom dropdown input placeholder
    this.#setupDropdownInputPlaceholder();

    // Setup clear button visibility (delay to ensure TomSelect is fully initialized)
    if (this.clearButtonValue) {
      setTimeout(() => this.#setupClearButton(), 50);
    }

    // Add data-flag attribute to items when they're added
    this.select.on("item_add", (value) => {
      this.#markFlaggedItem(value);
      if (this.enableFlagToggleValue) {
        this.#addFlagButtonToItem(value);
      }
    });

    // Mark pre-selected items as flagged if needed
    this.#markExistingFlaggedItems();

    // Add flag buttons to existing items if flag toggle is enabled
    if (this.enableFlagToggleValue) {
      setTimeout(() => this.#addFlagButtonsToExistingItems(), 50);
    }

    // Setup form submission handler to include flag data
    if (this.enableFlagToggleValue) {
      this.#setupFormSubmissionHandler();
    }
  }

  #setupFormSubmissionHandler() {
    const form = this.element.closest("form");
    if (!form) return;

    // Store reference to the handler so we can remove it later
    this.formSubmitHandler = (e) => {
      this.#addFlagDataToForm(form);
    };

    form.addEventListener("submit", this.formSubmitHandler);
  }

  #addFlagDataToForm(form) {
    // Remove any existing flag inputs for this select
    const existingInputs = form.querySelectorAll(`input[name="${this.element.name}_flags[]"]`);
    existingInputs.forEach((input) => input.remove());

    // Get all selected values
    const selectedValues = this.select.getValue();
    const values = Array.isArray(selectedValues) ? selectedValues : [selectedValues].filter(Boolean);

    // Add hidden inputs for flagged items
    values.forEach((value) => {
      const option = this.select.options[value];
      if (option?.$option?.dataset?.flag === "true") {
        const hiddenInput = document.createElement("input");
        hiddenInput.type = "hidden";
        hiddenInput.name = `${this.element.name}_flags[]`;
        hiddenInput.value = value;
        form.appendChild(hiddenInput);
      }
    });
  }

  #markFlaggedItem(value) {
    const option = this.select.options[value];
    if (option?.$option?.dataset?.flag === "true") {
      // Find the item element and add the data-flag attribute
      const itemElement = this.select.control.querySelector(`[data-value="${value}"]`);
      if (itemElement) {
        itemElement.setAttribute("data-flag", "true");
      }
    }
  }

  #markExistingFlaggedItems() {
    // Check all currently selected items and mark them as flagged if needed
    const selectedValues = this.select.getValue();
    const values = Array.isArray(selectedValues) ? selectedValues : [selectedValues].filter(Boolean);

    values.forEach((value) => {
      // Small delay to ensure TomSelect has rendered the items
      setTimeout(() => this.#markFlaggedItem(value), 0);
    });
  }

  #addFlagButtonsToExistingItems() {
    const selectedValues = this.select.getValue();
    const values = Array.isArray(selectedValues) ? selectedValues : [selectedValues].filter(Boolean);

    values.forEach((value) => {
      this.#addFlagButtonToItem(value);
    });
  }

  #addFlagButtonToItem(value) {
    if (!this.element.multiple) return; // Only for multi-select

    const itemElement = this.select.control.querySelector(`[data-value="${value}"]`);
    if (!itemElement) return;

    // Check if flag button already exists
    if (itemElement.querySelector(".flag-toggle")) return;

    // Check if item is currently flagged
    const isFlagged = itemElement.dataset.flag === "true";

    // Create flag toggle button
    const flagButton = document.createElement("button");
    flagButton.type = "button";
    flagButton.className =
      "flag-toggle flex size-[18px] items-center justify-center rounded hover:bg-neutral-200 dark:hover:bg-neutral-700 text-neutral-600 dark:text-neutral-400 -mr-0.5";
    flagButton.innerHTML = isFlagged ? this.#getFlaggedIcon() : this.#getUnflaggedIcon();

    // Add click handler
    flagButton.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.#toggleItemFlag(value, itemElement, flagButton);
    });

    // Insert before the remove button
    const removeButton = itemElement.querySelector(".remove");
    if (removeButton) {
      removeButton.parentNode.insertBefore(flagButton, removeButton);
    }
  }

  #getUnflaggedIcon() {
    return `
      <svg xmlns="http://www.w3.org/2000/svg" class="size-3" width="12" height="12" viewBox="0 0 12 12"><g fill="currentColor"><rect x=".751" y="5.25" width="10.499" height="1.5" transform="translate(-2.485 6) rotate(-45)" stroke-width="0"></rect><path d="m6,12c-3.309,0-6-2.691-6-6S2.691,0,6,0s6,2.691,6,6-2.691,6-6,6Zm0-10.5C3.519,1.5,1.5,3.519,1.5,6s2.019,4.5,4.5,4.5,4.5-2.019,4.5-4.5S8.481,1.5,6,1.5Z" stroke-width="0"></path></g></svg>
    `;
  }

  #getFlaggedIcon() {
    return `
      <svg xmlns="http://www.w3.org/2000/svg" class="size-3" width="12" height="12" viewBox="0 0 12 12"><g fill="currentColor"><rect x=".751" y="5.25" width="10.499" height="1.5" transform="translate(-2.485 6) rotate(-45)" stroke-width="0"></rect><path d="m6,12c-3.309,0-6-2.691-6-6S2.691,0,6,0s6,2.691,6,6-2.691,6-6,6Zm0-10.5C3.519,1.5,1.5,3.519,1.5,6s2.019,4.5,4.5,4.5,4.5-2.019,4.5-4.5S8.481,1.5,6,1.5Z" stroke-width="0"></path></g></svg>
    `;
  }

  #updateDropdownOptionStyling(value, isFlagged) {
    // Find the dropdown option element
    if (!this.select?.dropdown_content) return;

    const dropdownOption = this.select.dropdown_content.querySelector(`[data-value="${value}"]`);
    if (!dropdownOption) return;

    // Find the span element that contains the text (not the checkbox)
    const textSpan = dropdownOption.querySelector("span:not(.tomselect-checkbox)");
    if (!textSpan) return;

    // Update the text color classes
    if (isFlagged) {
      // Add red text classes
      textSpan.classList.add("text-red-600", "dark:text-red-400");
    } else {
      // Remove red text classes
      textSpan.classList.remove("text-red-600", "dark:text-red-400");
    }
  }

  #toggleItemFlag(value, itemElement, flagButton) {
    const option = this.select.options[value];
    const currentFlag = itemElement.dataset.flag === "true";
    const newFlag = !currentFlag;

    // Update item element
    if (newFlag) {
      itemElement.setAttribute("data-flag", "true");
      itemElement.classList.add("!bg-red-100", "!text-red-900");
      itemElement.classList.add("dark:!bg-[#281212]", "dark:!text-red-200");
    } else {
      itemElement.removeAttribute("data-flag");
      itemElement.classList.remove("!bg-red-100", "!text-red-900");
      itemElement.classList.remove("dark:!bg-[#281212]", "dark:!text-red-200");
    }

    // Update flag button icon
    if (flagButton) {
      flagButton.innerHTML = newFlag ? this.#getFlaggedIcon() : this.#getUnflaggedIcon();
    }

    // Update original option element's data-flag attribute
    // This persists the flag state back to the <option> element in the DOM
    if (option?.$option) {
      if (newFlag) {
        option.$option.setAttribute("data-flag", "true");
        option.$option.dataset.flag = "true";
      } else {
        option.$option.removeAttribute("data-flag");
        delete option.$option.dataset.flag;
      }
    }

    // Update dropdown option styling if dropdown is open
    this.#updateDropdownOptionStyling(value, newFlag);

    // Update external tags if they exist
    if (this.externalTagsContainer) {
      this.#updateExternalTags();
    }

    // Dispatch custom event for external listeners
    this.element.dispatchEvent(
      new CustomEvent("flag-toggled", {
        detail: { value, flagged: newFlag },
        bubbles: true,
      })
    );
  }

  #toggleExternalTagFlag(value, tagElement) {
    const option = this.select.options[value];
    const currentFlag = tagElement.dataset.flag === "true";
    const newFlag = !currentFlag;

    // Update original option element's data-flag attribute
    // This persists the flag state back to the <option> element in the DOM
    if (option?.$option) {
      if (newFlag) {
        option.$option.setAttribute("data-flag", "true");
        option.$option.dataset.flag = "true";
      } else {
        option.$option.removeAttribute("data-flag");
        delete option.$option.dataset.flag;
      }
    }

    // Update dropdown option styling if dropdown is open
    this.#updateDropdownOptionStyling(value, newFlag);

    // Find the corresponding internal item and update it
    const itemElement = this.select.control.querySelector(`[data-value="${value}"]`);
    if (itemElement) {
      if (newFlag) {
        itemElement.setAttribute("data-flag", "true");
        itemElement.classList.add("!bg-red-100", "!text-red-900");
        itemElement.classList.add("dark:!bg-[#281212]", "dark:!text-red-200");
      } else {
        itemElement.removeAttribute("data-flag");
        itemElement.classList.remove("!bg-red-100", "!text-red-900");
        itemElement.classList.remove("dark:!bg-[#281212]", "dark:!text-red-200");
      }
    }

    // Re-render external tags to reflect the change
    this.#updateExternalTags();

    // Dispatch custom event for external listeners
    this.element.dispatchEvent(
      new CustomEvent("flag-toggled", {
        detail: { value, flagged: newFlag },
        bubbles: true,
      })
    );
  }

  #setupPositioning() {
    this.scrollHandler = () => this.#updatePosition();
    window.addEventListener("scroll", this.scrollHandler, true);

    this.resizeObserver = new ResizeObserver(() => this.#updatePosition());
    this.resizeObserver.observe(document.documentElement);

    this.mutationObserver = new MutationObserver(() => {
      if (this.select?.dropdown?.classList.contains("ts-dropdown")) {
        this.#updatePosition();
      }
    });
    this.mutationObserver.observe(document.body, { childList: true, subtree: true });
  }

  #handleDropdownOpen() {
    // Only clear active states if no item was just selected
    if (!this.justSelectedItem) {
      this.#clearAllActiveStates();
      this.select.setActiveOption(null);
    }
    this.justSelectedItem = false; // Reset the flag

    // Update position multiple times to ensure proper placement
    [0, 10, 50, 100].forEach((delay) => {
      setTimeout(() => this.#updatePosition(), delay);
    });

    if (this.hasUrlValue && !this.virtualScrollValue) {
      this.#setupInfiniteScroll();
      this.#resetPagination();
    }
  }

  #setupInfiniteScroll() {
    const content = this.select.dropdown_content;
    if (!content) return;

    const handler = this.#handleScroll.bind(this);
    content.removeEventListener("scroll", handler);
    content.addEventListener("scroll", handler);
  }

  #handleScroll() {
    if (this.virtualScrollValue || !this.select?.dropdown_content) return;

    const { scrollTop, scrollHeight, clientHeight } = this.select.dropdown_content;
    if (scrollTop + clientHeight >= scrollHeight - 50) {
      const query = this.select.control_input?.value || "";
      this.#loadMore(query);
    }
  }

  async #loadMore(query) {
    if (this.virtualScrollValue || this.loadingMore || !this.hasMore) return;

    this.loadingMore = true;
    this.currentPage += 1;

    const lastActiveValue = this.#getActiveValue();

    try {
      const response = await this.#fetchPage(query, this.currentPage);
      const newOptions = this.#transformApiResponse(response);

      if (newOptions?.data?.length > 0) {
        this.select.addOptions(newOptions.data);
        this.hasMore = newOptions.has_more;

        setTimeout(() => this.#restoreSelectionAfterLoading(lastActiveValue), 300);
      } else {
        this.hasMore = false;
      }

      this.select.control_input?.focus();
    } catch (error) {
      console.error("Load more error:", error);
      this.hasMore = false;
    } finally {
      this.loadingMore = false;
      this.#updatePosition();
    }
  }

  #setupScrollTracking() {
    const content = this.select.dropdown_content;
    if (!content) return;

    content.addEventListener("scroll", () => {
      this.lastScrollPosition = content.scrollTop;
    });

    ["item_add", "item_remove"].forEach((event) => {
      this.select.on(event, () => {
        if (this.lastScrollPosition) {
          setTimeout(() => {
            content.scrollTop = this.lastScrollPosition;
          }, 0);
        }
      });
    });
  }

  #setupReadonlyInput() {
    // Only apply readonly to the main control input, not the dropdown input
    const mainInput = this.select.control.querySelector("input:not(.dropdown-input)");
    if (!mainInput) return;

    mainInput.readOnly = true;
    mainInput.setAttribute("readonly", "readonly");

    let buffer = "";
    let timeout;

    mainInput.addEventListener("keydown", (e) => {
      if (!this.#isNavigationKey(e.key)) return;

      if (e.key.length === 1) {
        document.body.requestPointerLock();
        this.#handleTypeAhead(e.key, buffer, timeout);
      }
    });

    document.addEventListener("mousemove", () => {
      if (document.pointerLockElement) document.exitPointerLock();
    });
  }

  #setupCountDisplay() {
    // Create count element
    this.countElement = document.createElement("div");
    this.countElement.className = "ts-count-display";

    // Insert count element into the control
    this.select.control.appendChild(this.countElement);

    // Update count on initial load
    this.#updateCountDisplay();

    // Listen for changes and prevent dropdown from closing
    this.select.on("item_add", () => {
      this.#updateCountDisplay();
      // Force dropdown to stay open after selection
      setTimeout(() => {
        if (!this.select.isOpen) {
          this.select.open();
        }
      }, 0);
    });

    this.select.on("item_remove", () => this.#updateCountDisplay());
  }

  #setupDropdownInputPlaceholder() {
    // Set the dropdown input placeholder after TomSelect is initialized
    const setPlaceholder = () => {
      const dropdownInput = this.select.dropdown?.querySelector(".dropdown-input");
      if (dropdownInput && this.dropdownInputPlaceholderValue) {
        dropdownInput.placeholder = this.dropdownInputPlaceholderValue;
      }
    };

    // Set immediately if dropdown already exists
    setPlaceholder();

    // Also set when dropdown opens (in case it's created dynamically)
    this.select.on("dropdown_open", setPlaceholder);

    // Ensure search icon is present alongside the dropdown input
    const setIcon = () => {
      const dropdownInput = this.select.dropdown?.querySelector(".dropdown-input");
      if (dropdownInput) {
        this.#addSearchIconToDropdownInput(dropdownInput);
        // Setup observer to re-add icon if it gets removed (e.g., by macOS emoji picker)
        this.#setupSearchIconObserver(dropdownInput);
      }
    };

    // Add immediately if dropdown already exists
    setIcon();

    // Also add when dropdown opens
    this.select.on("dropdown_open", setIcon);
  }

  #setupSearchIconObserver(dropdownInput) {
    // Clean up existing observer if any
    if (this.searchIconObserver) {
      this.searchIconObserver.disconnect();
    }

    const wrap = dropdownInput.closest(".dropdown-input-wrap") || dropdownInput.parentElement;
    if (!wrap) return;

    // Create observer to watch for the icon being removed
    this.searchIconObserver = new MutationObserver((mutations) => {
      // Check if the icon still exists
      const iconExists = wrap.querySelector(".dropdown-input-search-icon");
      if (!iconExists && this.select?.isOpen) {
        // Icon was removed while dropdown is open, re-add it
        this.#addSearchIconToDropdownInput(dropdownInput);
      }
    });

    // Observe child list changes in the wrap element
    this.searchIconObserver.observe(wrap, {
      childList: true,
      subtree: false,
    });
  }

  #preventNativeFocus() {
    // Prevent native select from being focused (e.g., after form validation)
    // and immediately transfer focus to TomSelect control
    this.element.addEventListener("focus", (e) => {
      e.preventDefault();
      e.stopPropagation();

      // Transfer focus to the TomSelect control
      if (this.select?.control_input) {
        this.select.control_input.focus();
      } else if (this.select?.control) {
        this.select.control.focus();
      }
    }, true);

    // Also prevent arrow keys on the native select from opening native dropdown
    this.element.addEventListener("keydown", (e) => {
      if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", " ", "Enter"].includes(e.key)) {
        e.preventDefault();
        e.stopPropagation();

        // Open TomSelect dropdown instead
        if (this.select && !this.select.isOpen) {
          this.select.open();
        }
      }
    }, true);
  }

  #setupClearButton() {
    // Don't show clear button for multiple selects
    if (this.element.multiple) return;

    // Don't show clear button if the select is disabled
    if (this.element.disabled) return;

    // Create the clear button dynamically
    this.#createClearButton();

    // Initial visibility check
    this.#updateClearButtonVisibility();

    // Listen for input changes (typing)
    this.select.on("input", () => {
      this.#updateClearButtonVisibility();
    });

    // Listen for value changes (selection)
    this.select.on("change", () => {
      this.#updateClearButtonVisibility();
    });

    // Listen for item add/remove (for single selects that might have items)
    this.select.on("item_add", () => {
      this.#updateClearButtonVisibility();
    });

    this.select.on("item_remove", () => {
      this.#updateClearButtonVisibility();
    });

    // Listen for dropdown open/close to update visibility
    this.select.on("dropdown_open", () => {
      // Immediate check when dropdown opens
      this.#updateClearButtonVisibility();
      // Also check after a small delay to catch any delayed state changes
      setTimeout(() => {
        this.#updateClearButtonVisibility();
      }, 5);
    });

    this.select.on("dropdown_close", () => {
      // Small delay to ensure TomSelect has finished processing
      setTimeout(() => {
        this.#updateClearButtonVisibility();
      }, 10);
    });

    // Listen for type-ahead and search events
    this.select.on("type", () => {
      this.#updateClearButtonVisibility();
    });

    // Also listen directly to the control input for typing
    if (this.select.control_input) {
      this.select.control_input.addEventListener("input", () => {
        this.#updateClearButtonVisibility();
      });

      // Listen for keydown events to catch ESC key and immediate typing
      this.select.control_input.addEventListener("keydown", (e) => {
        if (e.key === "Escape") {
          // Small delay to let TomSelect process the ESC key first
          setTimeout(() => {
            this.#updateClearButtonVisibility();
          }, 10);
        } else if (e.key.length === 1 && this.select.isOpen) {
          // Only show button immediately if dropdown is open (actual typing)
          this.clearButton.classList.remove("hidden");
          this.clearButton.classList.add("flex");
        }
      });
    }

    // Also listen to the main control for immediate keydown detection
    const mainControl = this.select.control;
    if (mainControl) {
      mainControl.addEventListener("keydown", (e) => {
        if (e.key.length === 1 && this.select.isOpen) {
          // Only show button immediately if dropdown is open (actual typing)
          this.clearButton.classList.remove("hidden");
          this.clearButton.classList.add("flex");
        }
      });
    }
  }

  #createClearButton() {
    // Find the ts-wrapper div
    const tsWrapper = this.element.parentElement?.querySelector(".ts-wrapper");
    if (!tsWrapper) {
      // Retry after a short delay
      setTimeout(() => this.#createClearButton(), 100);
      return;
    }

    // Create the clear button
    this.clearButton = document.createElement("button");
    this.clearButton.type = "button";
    this.clearButton.className =
      "hidden absolute items-center justify-center size-5 right-2 top-2.5 rounded-full text-neutral-500 hover:text-neutral-400 focus-visible:outline-2 focus-visible:outline-offset-0 focus-visible:outline-neutral-600 dark:focus-visible:outline-neutral-200 z-10 bg-white dark:bg-neutral-700 dark:text-neutral-400 dark:hover:text-neutral-500";
    this.clearButton.setAttribute("data-select-target", "clearButton");

    // Add the SVG icon
    this.clearButton.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" class="size-3" width="12" height="12" viewBox="0 0 12 12">
        <g fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" stroke="currentColor">
          <line x1="2.25" y1="9.75" x2="9.75" y2="2.25"></line>
          <line x1="9.75" y1="9.75" x2="2.25" y2="2.25"></line>
        </g>
      </svg>
    `;

    // Add click event listener
    this.clearButton.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.clearInput();
    });

    // Append to ts-wrapper
    tsWrapper.appendChild(this.clearButton);
  }

  #addSearchIconToDropdownInput(dropdownInput) {
    const wrap = dropdownInput.closest(".dropdown-input-wrap") || dropdownInput.parentElement;
    if (!wrap) return;

    // Ensure relative positioning for absolute icon placement
    wrap.classList.add("relative");

    // Avoid duplicating the icon
    if (wrap.querySelector(".dropdown-input-search-icon")) return;

    // Create the icon container
    const icon = document.createElement("span");
    icon.className =
      "dropdown-input-search-icon pointer-events-none absolute left-2.5 top-3 text-neutral-400 dark:text-neutral-300";
    icon.setAttribute("aria-hidden", "true");
    icon.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" class="size-3.5 sm:size-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
      </svg>
    `;

    // Insert icon before the input
    wrap.insertBefore(icon, dropdownInput);

    // Add left padding to the input so text doesn't overlap the icon
    dropdownInput.classList.add("!pl-8");
  }

  #updateClearButtonVisibility() {
    if (!this.clearButtonValue || this.element.multiple || this.element.disabled || !this.clearButton) return;

    const hasValue = this.select.getValue() && this.select.getValue() !== "";
    const hasInput = this.select.control_input?.value && this.select.control_input.value.trim() !== "";
    const isDropdownOpen = this.select.isOpen;
    const hasActiveSearch = this.select.lastQuery && this.select.lastQuery.trim() !== "";

    // Additional check: if dropdown is closed and no value is selected, hide the button
    const shouldShow = hasValue || (isDropdownOpen && (hasInput || hasActiveSearch));

    if (shouldShow) {
      this.clearButton.classList.remove("hidden");
      this.clearButton.classList.add("flex");
    } else {
      this.clearButton.classList.add("hidden");
      this.clearButton.classList.remove("flex");
    }
  }

  #updateCountDisplay() {
    const count = Object.keys(this.select.getValue()).length;

    if (count > 0) {
      // Use singular text if provided and count is 1, otherwise use regular countText
      const textToUse = count === 1 && this.countTextSingularValue ? this.countTextSingularValue : this.countTextValue;

      this.countElement.textContent = `${count} ${textToUse}`;
      this.select.control.classList.add("count-active");
    } else {
      this.select.control.classList.remove("count-active");
    }
  }

  #setupExternalTags() {
    // Create external tags container
    this.externalTagsContainer = document.createElement("div");

    const position = this.tagsPositionValue;
    const isAbove = position === "above";
    const isBelow = position === "below";
    const isCustomContainer = !isAbove && !isBelow;

    // Set up classes based on position type
    if (isCustomContainer) {
      // Custom container doesn't need margin classes
      this.externalTagsContainer.className = "external-tags-container flex flex-wrap gap-2";
    } else {
      const positionClass = isAbove ? "mb-2" : "mt-2";
      this.externalTagsContainer.className = `external-tags-container ${positionClass} flex flex-wrap gap-2`;
    }

    // Insert into custom container or relative to ts-wrapper
    if (isCustomContainer) {
      const customContainer = document.getElementById(position);
      if (!customContainer) {
        console.warn(`Custom container with id "${position}" not found. Falling back to "below" position.`);

        // Display error message to user
        const tsWrapper = this.element.parentElement?.querySelector(".ts-wrapper");
        if (!tsWrapper) {
          setTimeout(() => this.#setupExternalTags(), 100);
          return;
        }

        // Create error message
        const errorMessage = document.createElement("div");
        errorMessage.className = "mt-1 text-sm text-red-600 dark:text-red-400";
        errorMessage.textContent = `Error: Container with id "${position}" not found. Using default position.`;
        tsWrapper.parentElement.insertBefore(errorMessage, tsWrapper.nextSibling);

        // Store reference for cleanup
        this.customContainerError = errorMessage;

        // Fall back to below position
        tsWrapper.parentElement.insertBefore(this.externalTagsContainer, errorMessage.nextSibling);
      } else {
        // Append to custom container
        customContainer.appendChild(this.externalTagsContainer);
      }
    } else {
      // Standard above/below positioning
      const tsWrapper = this.element.parentElement?.querySelector(".ts-wrapper");
      if (!tsWrapper) {
        setTimeout(() => this.#setupExternalTags(), 100);
        return;
      }

      if (isAbove) {
        tsWrapper.parentElement.insertBefore(this.externalTagsContainer, tsWrapper);
      } else {
        tsWrapper.parentElement.insertBefore(this.externalTagsContainer, tsWrapper.nextSibling);
      }
    }

    // Hide tags inside the control
    this.select.control.classList.add("external-tags-active");

    // Initial render
    this.#updateExternalTags();

    // Listen for changes
    this.select.on("item_add", () => this.#updateExternalTags());
    this.select.on("item_remove", () => this.#updateExternalTags());
  }

  #updateExternalTags() {
    if (!this.externalTagsContainer) return;

    // Clear existing tags
    this.externalTagsContainer.innerHTML = "";

    // Get selected values
    const values = this.select.getValue();
    if (!values || (Array.isArray(values) && values.length === 0)) {
      // Hide container when empty
      this.externalTagsContainer.style.display = "none";
      return;
    }

    // Show container when there are tags
    this.externalTagsContainer.style.display = "flex";

    // Convert to array if needed
    const valueArray = Array.isArray(values) ? values : [values];

    // Render each tag
    valueArray.forEach((value) => {
      const option = this.select.options[value];
      if (!option) return;

      const tag = this.#createExternalTag(value, option);
      this.externalTagsContainer.appendChild(tag);
    });
  }

  #createExternalTag(value, option) {
    const tag = document.createElement("div");
    const isFlagged = option.$option?.dataset?.flag === "true";
    const tagClass = isFlagged
      ? "inline-flex items-center gap-1 rounded-md bg-red-100 pl-2 pr-1 py-1 text-xs font-medium text-red-900 dark:bg-[#281212] dark:text-red-200 *:text-red-900 dark:*:text-red-200"
      : "inline-flex items-center gap-1 rounded-md bg-neutral-100 pl-2 pr-1 py-1 text-xs font-medium text-neutral-900 dark:bg-neutral-900 dark:text-neutral-100";
    tag.className = tagClass;
    tag.setAttribute("data-value", value);
    if (isFlagged) {
      tag.setAttribute("data-flag", "true");
    }

    // Get label from option
    const optionData = this.#parseOptionData(option);
    const label = optionData?.name || option[this.labelFieldValue] || option.text || value;

    // Add icon if available
    if (optionData?.icon) {
      const iconSpan = document.createElement("span");
      iconSpan.innerHTML = optionData.icon;
      tag.appendChild(iconSpan);
    }

    // Add label
    const labelSpan = document.createElement("span");
    labelSpan.textContent = label;
    tag.appendChild(labelSpan);

    // Add flag toggle button if enabled
    if (this.enableFlagToggleValue) {
      const flagBtn = document.createElement("button");
      flagBtn.type = "button";
      const flagBtnClass = isFlagged
        ? "flex size-[18px] items-center justify-center rounded hover:bg-red-200 dark:hover:bg-red-100/10 text-red-700 dark:text-red-300"
        : "flex size-[18px] items-center justify-center rounded hover:bg-neutral-200 dark:hover:bg-neutral-800 text-neutral-600 dark:text-neutral-400";
      flagBtn.className = flagBtnClass;
      flagBtn.innerHTML = isFlagged ? this.#getFlaggedIcon() : this.#getUnflaggedIcon();

      flagBtn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.#toggleExternalTagFlag(value, tag);
      });

      tag.appendChild(flagBtn);
    }

    // Add remove button
    const removeBtn = document.createElement("button");
    removeBtn.type = "button";
    const removeBtnClass = isFlagged
      ? "flex size-[18px] items-center justify-center rounded hover:bg-red-200 dark:hover:bg-red-100/10 text-red-700 dark:text-red-300"
      : "flex size-[18px] items-center justify-center rounded hover:bg-neutral-200 dark:hover:bg-neutral-800 text-neutral-600 dark:text-neutral-400";
    removeBtn.className = removeBtnClass;
    removeBtn.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" class="size-3" viewBox="0 0 12 12" fill="currentColor">
        <path d="m2.25,10.5c-.192,0-.384-.073-.53-.22-.293-.293-.293-.768,0-1.061L9.22,1.72c.293-.293.768-.293,1.061,0s.293.768,0,1.061l-7.5,7.5c-.146.146-.338.22-.53.22Z" stroke-width="0"></path>
        <path d="m9.75,10.5c-.192,0-.384-.073-.53-.22L1.72,2.78c-.293-.293-.293-.768,0-1.061s.768-.293,1.061,0l7.5,7.5c.293.293.293.768,0,1.061-.146.146-.338.22-.53.22Z" stroke-width="0"></path>
      </svg>
    `;

    removeBtn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.select.removeItem(value);
    });

    tag.appendChild(removeBtn);

    return tag;
  }

  #handleTypeAhead(key, buffer, timeout) {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      buffer = "";
    }, 1000);

    buffer += key.toLowerCase();
    const match = this.#findMatchingOption(buffer);

    if (match) {
      const optionEl = this.select.dropdown_content.querySelector(`[data-value="${match[this.valueFieldValue]}"]`);

      if (optionEl) {
        this.select.setActiveOption(optionEl);
        this.select.open();
        this.#scrollToOption(optionEl);
      }
    }
  }

  #addScrollButtons() {
    const createButton = (direction, position) => {
      const btn = document.createElement("div");
      btn.className = `absolute left-0 right-0 ${position} h-5 bg-gradient-to-${
        direction === "up" ? "b" : "t"
      } from-white to-transparent dark:from-neutral-800 z-10 cursor-default flex items-center justify-center transition-opacity duration-150`;
      btn.innerHTML = `<svg class="size-3 text-neutral-600 dark:text-neutral-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M${
        direction === "up" ? "5 15l7-7 7 7" : "19 9l-7 7-7-7"
      }"></path></svg>`;
      return btn;
    };

    const scrollUpBtn = createButton("up", "top-0");
    const scrollDownBtn = createButton("down", "bottom-0");

    let scrollInterval;
    const scrollSpeed = 80;

    const setupScrollButton = (btn, direction) => {
      const startScroll = () => {
        if (scrollInterval) clearInterval(scrollInterval);
        scrollInterval = setInterval(() => {
          this.select.dropdown_content.scrollTop += direction === "up" ? -scrollSpeed : scrollSpeed;
        }, 100);
        btn.style.opacity = "0.7";
      };

      const stopScroll = () => {
        if (scrollInterval) {
          clearInterval(scrollInterval);
          scrollInterval = null;
        }
        btn.style.opacity = "1";
      };

      // Mouse events
      btn.addEventListener("mouseenter", startScroll);
      btn.addEventListener("mouseleave", stopScroll);

      // Touch events
      ["touchstart", "touchend", "touchcancel"].forEach((event) => {
        btn.addEventListener(
          event,
          (e) => {
            e.preventDefault();
            event === "touchstart" ? startScroll() : stopScroll();
          },
          { passive: false }
        );
      });
    };

    setupScrollButton(scrollUpBtn, "up");
    setupScrollButton(scrollDownBtn, "down");

    this.select.dropdown.insertBefore(scrollUpBtn, this.select.dropdown.firstChild);
    this.select.dropdown.appendChild(scrollDownBtn);

    // Show/hide based on scroll
    this.select.dropdown_content.addEventListener("scroll", () => {
      const { scrollTop, scrollHeight, clientHeight } = this.select.dropdown_content;
      scrollUpBtn.style.display = scrollTop > 0 ? "flex" : "none";
      scrollDownBtn.style.display = scrollTop + clientHeight < scrollHeight ? "flex" : "none";
    });

    scrollUpBtn.style.display = "none";
  }

  async #updatePosition() {
    if (!this.select?.dropdown) return;

    // Don't reposition during infinite scroll loading
    if (this.select.dropdown_content?.classList.contains("is-loading-more")) return;

    const reference = this.select.control;
    const floating = this.select.dropdown;

    if (!reference.getBoundingClientRect().height || !floating.getBoundingClientRect().height) {
      if (floating.offsetParent !== null) {
        setTimeout(() => this.#updatePosition(), 50);
      }
      return;
    }

    try {
      // Determine placement based on external tags position
      let placement = "bottom-start";
      if (this.tagsPositionValue !== "inline") {
        const position = this.tagsPositionValue;
        // Only adjust placement for standard above/below positions, not custom containers
        if (position === "above") {
          placement = "bottom-start"; // Tags are above, dropdown below
        } else if (position === "below") {
          placement = "top-start"; // Tags are below, dropdown above
        }
        // For custom container IDs, keep default "bottom-start"
      }

      const { x, y } = await computePosition(reference, floating, {
        placement,
        middleware: [offset(6), flip(), shift({ padding: 8 })],
      });

      Object.assign(floating.style, {
        position: "absolute",
        left: `${x}px`,
        top: `${y}px`,
        width: `${Math.max(reference.offsetWidth, 160)}px`,
      });
    } catch (error) {
      console.warn("Position update error:", error);
    }
  }

  #handleChange(value) {
    // Set flag to indicate an item was just selected
    this.justSelectedItem = true;

    if (value === "none") {
      this.element.value = "";
      if (this.submitOnChangeValue) {
        const url = new URL(window.location.href);
        url.searchParams.delete(this.element.name);
        window.location.href = url.toString();
      }
    } else {
      if (this.submitOnChangeValue) {
        this.element.form.requestSubmit();
        this.element.value = value;
        this.#addSpinner();
      }
      if (this.updateFieldValue) {
        this.#updateTargetField(value);
      }
    }
  }

  #updateTargetField(value) {
    const form = this.element.closest("form");
    if (!form) return;

    const targetField = this.updateFieldTargetValue
      ? form.querySelector(this.updateFieldTargetValue)
      : form.querySelector('input[name="list_contact[name]"]');

    if (!targetField) return;

    const selectedOption = this.select.options[value];
    if (!selectedOption) return;

    const data = this.#parseOptionData(selectedOption);
    if (data?.[this.updateFieldSourceValue]) {
      targetField.value = data[this.updateFieldSourceValue];
      targetField.dispatchEvent(new Event("input", { bubbles: true }));
    }
  }

  #parseOptionData(option) {
    if (typeof option.text === "string" && option.text.startsWith("{")) {
      try {
        return JSON.parse(option.text);
      } catch (e) {
        console.warn("Parse error:", e);
      }
    }
    return null;
  }

  #addSpinner() {
    const container = this.element.closest(".relative")?.querySelector(".absolute.z-10");
    if (container) {
      container.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" class="animate-spin size-7 mr-[5px] text-neutral-500 p-1 rounded-full bg-white dark:bg-neutral-700" width="24" height="24" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      `;
    }
  }

  #transformApiResponse(response) {
    const data = this.#extractDataArray(response);
    const transformedData = (data || []).map((item) => ({
      ...item,
      text: item.text || item[this.labelFieldValue] || item.name || "",
      value: item.value || item[this.valueFieldValue],
    }));

    if (!this.virtualScrollValue) {
      const hasMore = this.#detectHasMore(response, data);
      return { data: transformedData, has_more: hasMore };
    }

    return { data: transformedData };
  }

  #extractDataArray(response) {
    if (this.responseDataFieldValue !== "data") {
      return this.#getNestedValue(response, this.responseDataFieldValue);
    }

    if (Array.isArray(response)) return response;

    const fields = ["data", "results", "items"];
    for (const field of fields) {
      if (response[field] && Array.isArray(response[field])) {
        return response[field];
      }
    }

    return null;
  }

  #detectHasMore(response, data) {
    return (
      response.has_more ||
      response.hasMore ||
      !!response.next ||
      !!response.next_page_url ||
      (response.info && !!response.info.next) ||
      (data && data.length === this.perPageValue) ||
      false
    );
  }

  #buildApiUrl(baseUrl, query, page) {
    const url = new URL(baseUrl, window.location.origin);

    if (query) url.searchParams.set(this.searchParamValue, query);
    url.searchParams.set("page", page);

    const isExternalApi = !baseUrl.startsWith("/") && !baseUrl.startsWith(window.location.origin);
    if (!isExternalApi) {
      url.searchParams.set("per_page", this.perPageValue);
    }

    return url.toString();
  }

  async #fetchPage(query, page) {
    const url = this.#buildApiUrl(this.urlValue, query, page);
    const response = await fetch(url);
    if (!response.ok) throw new Error(response.statusText);
    return response.json();
  }

  #renderStandardOption(data, escape) {
    const optionData = this.#parseOptionData(data);
    const isFlagged = data.$option?.dataset?.flag === "true";
    const textClass = isFlagged ? "text-red-600 dark:text-red-400" : "";

    if (optionData) {
      return `<div class='flex items-center gap-y-[3px] gap-x-1.5 flex-wrap'>
        ${optionData.icon || ""}
        <span class='${textClass}'>${escape(optionData.name)}</span>
        ${optionData.side || ""}
        ${
          optionData.description
            ? `<p class='text-neutral-500 dark:text-neutral-300 text-xs my-0 w-full'>${escape(
                optionData.description
              )}</p>`
            : ""
        }
      </div>`;
    }

    return `<div class='flex items-center gap-1.5'><span class='${textClass}'>${escape(data.text)}</span></div>`;
  }

  #renderStandardItem(data, escape) {
    const optionData = this.#parseOptionData(data);
    const isFlagged = data.$option?.dataset?.flag === "true";
    const itemClass = isFlagged
      ? "!flex items-center gap-1.5 !bg-red-100 !text-red-900 dark:!bg-[#281212] dark:!text-red-200"
      : "!flex items-center gap-1.5";

    if (optionData) {
      return `<div class='${itemClass}'>
        ${optionData.icon || ""}
        <span>${escape(optionData.name)}</span>
      </div>`;
    }

    return `<div class='${itemClass}'><span class='line-clamp-1'>${escape(data.text)}</span></div>`;
  }

  #renderImageItem(data, escape) {
    const label = data[this.labelFieldValue] || data.name || data.text;
    const isFlagged = data.$option?.dataset?.flag === "true";
    const itemClass = isFlagged
      ? "!flex items-center gap-2 !bg-red-100 !text-red-900 dark:!bg-[#281212] dark:!text-red-200 *:text-red-900 dark:*:text-red-200"
      : "!flex items-center gap-2";
    return `<div class='${itemClass}'>
      <img class='size-5 rounded-full' src='${escape(data[this.imageFieldValue])}' alt='${escape(label)}'>
      <span class='line-clamp-1'>${escape(label)}</span>
    </div>`;
  }

  #renderApiOption(data, escape) {
    const hasImage = this.imageFieldValue && data[this.imageFieldValue];
    const label = data[this.labelFieldValue] || data.name || data.text;
    const isFlagged = data.$option?.dataset?.flag === "true";
    const labelClass = isFlagged ? "font-medium text-red-600 dark:text-red-400" : "font-medium";

    let html = `<div class='${hasImage ? "flex items-start gap-3" : ""} py-1'>`;

    if (hasImage) {
      html += `<img class='size-10 rounded-full flex-shrink-0' src='${escape(
        data[this.imageFieldValue]
      )}' alt='${escape(label)}'>`;
      html += `<div class='flex-1 min-w-0'>`;
    }

    html += `<div class='${labelClass}'>${escape(label)}</div>`;

    if (this.subtitleFieldValue && data[this.subtitleFieldValue]) {
      html += `<div class='text-xs text-neutral-500 dark:text-neutral-400'>${escape(data[this.subtitleFieldValue])}`;
      if (this.badgeFieldValue && data[this.badgeFieldValue]) {
        html += ` • ${escape(data[this.badgeFieldValue])}`;
      }
      html += `</div>`;
    }

    if (this.metaFieldsValue) {
      const metaValues = this.metaFieldsValue
        .split(",")
        .map((f) => f.trim())
        .filter((field) => data[field])
        .map((field) => escape(data[field]));

      if (metaValues.length > 0) {
        html += `<div class='text-xs text-neutral-500 dark:text-neutral-400'>${metaValues.join(" • ")}</div>`;
      }
    }

    if (hasImage) html += `</div>`;
    html += `</div>`;

    return html;
  }

  #renderWithTemplate(template, data, escape) {
    return template.replace(/\{\{(\w+)\}\}/g, (match, field) => (data[field] ? escape(data[field]) : ""));
  }

  #renderLoadingMore() {
    return `<div class="loading-more-results py-2 flex items-center justify-center text-sm text-neutral-500 dark:text-neutral-400">
      <svg class="animate-spin -ml-1 mr-3 h-4 w-4 text-neutral-500 dark:text-neutral-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>${this.loadingTextValue}
    </div>`;
  }

  // Helper methods

  #hasCustomFields() {
    return this.imageFieldValue || this.subtitleFieldValue || this.metaFieldsValue;
  }

  #isNavigationKey(key) {
    return (
      (key.length === 1 && key.match(/[a-z0-9]/i)) || ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(key)
    );
  }

  #getNestedValue(obj, path) {
    return path.split(".").reduce((current, key) => current?.[key], obj);
  }

  #clearAllActiveStates() {
    if (!this.select?.dropdown_content) return;

    // Clear both regular options and create option
    this.select.dropdown_content.querySelectorAll(".option.active, .create.active").forEach((opt) => {
      opt.classList.remove("active");
      opt.setAttribute("aria-selected", "false");
    });

    if (this.select.activeOption) {
      this.select.activeOption = null;
    }
  }

  #captureScrollState(url) {
    const currentUrl = new URL(url, window.location.origin);
    const currentPage = parseInt(currentUrl.searchParams.get("page") || "1");
    let state = { currentPage };

    // Early return if select is destroyed
    if (!this.select?.dropdown_content) return state;

    state.scrollTop = this.select.dropdown_content.scrollTop;
    state.scrollHandler = this.select.dropdown_content.onscroll;

    if (currentPage > 1) {
      const activeItem = this.select.dropdown_content.querySelector(".option.active");
      if (activeItem) {
        state.lastActiveValue = activeItem.getAttribute("data-value");
      }
    }

    this.select.dropdown_content.onscroll = null;
    this.select.dropdown_content.classList.add("is-loading-more");

    return state;
  }

  #restoreScrollState(state) {
    if (!this.select?.dropdown_content || !state) return;

    if (typeof state.scrollTop === "number") {
      this.select.dropdown_content.scrollTop = state.scrollTop;
    }

    this.select.dropdown_content.onscroll = state.scrollHandler;
  }

  #cleanupScrollState() {
    if (this.select?.dropdown_content) {
      this.select.dropdown_content.classList.remove("is-loading-more");
    }
  }

  #updateVirtualScrollState(url, query, json) {
    // Early return if select is destroyed
    if (!this.select) return;

    const currentUrl = new URL(url, window.location.origin);
    const currentPage = parseInt(currentUrl.searchParams.get("page") || "1");

    const hasMore = json.data.length === this.perPageValue || json.info?.next || json.next || json.has_more;

    if (hasMore) {
      const nextUrl = this.#buildApiUrl(this.urlValue, query, currentPage + 1);
      this.select.setNextUrl(query, nextUrl);
    } else {
      this.select.setNextUrl(query, null);
    }
  }

  #handlePostLoadFocus(query, scrollState) {
    if (!this.select?.dropdown_content) return;

    // Don't mess with focus/selection during infinite scroll
    if (scrollState.currentPage > 1) {
      // Just maintain the current scroll position
      return;
    }

    // Only clear active states if no item was just selected
    if (!this.justSelectedItem) {
      this.#clearAllActiveStates();
      this.select.setActiveOption(null);

      if (scrollState.currentPage === 1) {
        this.#focusFirstOption(query);
      }
    }
  }

  #focusFirstOption(query) {
    if (!query?.trim() || !this.select?.dropdown_content) return;

    const currentActive = this.select.dropdown_content.querySelector(".option.active");
    if (currentActive || this.select.activeOption) return;

    const firstOption = this.select.dropdown_content.querySelector(".option:not(.create):not(.no-results)");
    if (firstOption) {
      this.select.setActiveOption(firstOption);
    }
  }

  #restoreSelectionAfterLoading(lastActiveValue) {
    if (!this.select?.dropdown_content || !lastActiveValue) return;

    const currentActive = this.select.dropdown_content.querySelector(".option.active");
    if (currentActive) return;

    const itemToRestore = this.select.dropdown_content.querySelector(`[data-value="${lastActiveValue}"]`);
    if (itemToRestore) {
      this.select.setActiveOption(itemToRestore);
    }
  }

  #getActiveValue() {
    const activeItem = this.select?.dropdown_content?.querySelector(".option.active");
    return activeItem?.getAttribute("data-value");
  }

  #findMatchingOption(buffer) {
    return Object.values(this.select.options).find((option) => {
      const label = this.hasUrlValue
        ? option[this.labelFieldValue]
        : this.#parseOptionData(option)?.name || option.text;
      return label.toLowerCase().startsWith(buffer);
    });
  }

  #scrollToOption(optionEl) {
    const content = this.select.dropdown_content;
    if (!content) return;

    const contentRect = content.getBoundingClientRect();
    const optionRect = optionEl.getBoundingClientRect();

    // Calculate the option's position relative to the scrollable content
    // Use getBoundingClientRect to get accurate positions relative to viewport
    const optionRelativeTop = optionRect.top - contentRect.top;
    const optionRelativeBottom = optionRelativeTop + optionRect.height;
    const contentScrollTop = content.scrollTop;
    const contentHeight = contentRect.height;

    // Define padding: scroll when the option is within this distance from the edge
    const scrollPadding = optionRect.height * 1 + 6;

    // Check if we need to scroll down
    if (optionRelativeBottom > contentHeight - scrollPadding) {
      // Scroll so the option is visible with padding below
      content.scrollTop = contentScrollTop + (optionRelativeBottom - contentHeight + scrollPadding);
    }
    // Check if we need to scroll up
    else if (optionRelativeTop < scrollPadding) {
      // Scroll so the option is visible with padding above
      content.scrollTop = contentScrollTop + (optionRelativeTop - scrollPadding);
    }
  }

  #resetPagination() {
    this.currentPage = 1;
    this.hasMore = true;
    this.loadingMore = false;
  }

  #shouldLoadMore() {
    if (!this.select?.dropdown_content) return false;
    const { scrollTop, scrollHeight, clientHeight } = this.select.dropdown_content;
    return scrollTop + clientHeight + 150 >= scrollHeight;
  }

  #handleInitialValue() {
    if (!this.updateFieldValue || !this.hasUrlValue) return;

    try {
      const currentValue = this.getValue(this.urlValue);
      if (currentValue) {
        this.select.setValue(currentValue);
      }
    } catch (error) {
      console.warn("Initial value setting skipped");
    }
  }

  // Public methods

  clearInput() {
    if (!this.select) return;

    // Clean up search icon observer before destroying
    if (this.searchIconObserver) {
      this.searchIconObserver.disconnect();
      this.searchIconObserver = null;
    }

    // Simply reset the entire combobox to its initial state
    this.select.destroy();

    // Reinitialize the combobox with the same options
    const options = this.#buildOptions();
    this.select = new TomSelect(this.element, options);

    // Re-setup all the event handlers and features
    this.#setupEventHandlers();
    this.#setupPositioning();
    this.#handleInitialValue();

    // Hide the clear button
    this.#updateClearButtonVisibility();

    // Focus the input after a small delay to ensure TomSelect is fully initialized
    setTimeout(() => {
      if (this.dropdownInputValue) {
        // When dropdown input is enabled, focus the main control element
        // This will make it ready for interaction
        this.select.control?.focus();
      } else if (this.select.control_input) {
        // When dropdown input is disabled, focus the control input directly
        this.select.control_input.focus();
      } else {
        // Fallback: focus the main control element
        this.select.control?.focus();
      }
    }, 50);
  }

  // Private methods

  #cleanup() {
    if (this.checkboxObserver) this.checkboxObserver.disconnect();
    if (this.searchIconObserver) this.searchIconObserver.disconnect();
    if (this.select) {
      this.select.destroy();
      this.select = null;
    }

    // Clean up external tags container
    if (this.externalTagsContainer) {
      this.externalTagsContainer.remove();
      this.externalTagsContainer = null;
    }

    // Clean up custom container error message
    if (this.customContainerError) {
      this.customContainerError.remove();
      this.customContainerError = null;
    }

    // Clean up form submit handler
    if (this.formSubmitHandler) {
      const form = this.element.closest("form");
      if (form) {
        form.removeEventListener("submit", this.formSubmitHandler);
      }
      this.formSubmitHandler = null;
    }

    window.removeEventListener("scroll", this.scrollHandler, true);
    if (this.resizeObserver) this.resizeObserver.disconnect();
    if (this.mutationObserver) this.mutationObserver.disconnect();
  }
}
