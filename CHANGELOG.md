### 2021-12-27

* Support Rails 7.0
* Drop support for Rails 5.2 and earlier

### 2021-05-13

* Upgrade to Bootstrap 5
* Remove data-confirm-modal, not yet bootstrap 5 compatible
* Drop jQuery
* Include devise views directly

### 2021-03-04

* Switch to Madmin for admin area

### 2020-10-24

* Rescue from git configuration exception

### 2020-08-20

* Add tests for generating postgres and mysql apps

### 2020-08-07

* Refactor notifications to use the [Noticed gem](https://github.com/excid3/noticed)

### 2019-02-28

* Adds support for Rails 6.0
* Move all Javascript to Webpacker for Rails 5.2 and 6.0
  * Use Bootstrap, data-confirm-modal, and local-time from NPM packages
  * ProvidePlugin sets jQuery, $, and Rails variables for webpacker
* Use https://github.com/excid3/administrate fork of Administrate
  * Adds fix for zeitwerk autoloader in Rails 6
  * Adds support for virtual attributes
* Add Procfile, Procfile.dev and .foreman configs
* Add welcome message and instructions after completion

### 2019-01-02 and before

* Original version of Jumpstart
* Supported Rails 5.2 only
