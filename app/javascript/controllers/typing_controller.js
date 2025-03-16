// Customizable command palette for advanced users
// Opens with cmd+k or ctrl+k by default
// https://github.com/excid3/ninja-keys

import Typed from 'typed.js';

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typing"]
  connect() {
    const typed = new Typed(this.typingTarget, {
      strings: [
        '<b style="color: #7F4B8B">Sentry</b>',
        '<b style="color: #4F42DB">Dagster</b>',
        '<b style="color: #509EE2">Metabase</b>',
        '<b style="color: #EF5A27">Grafana</b>',
        '<b style="color: #E43820">Airflow</b>',
      ],
      typeSpeed: 50,
      loop: true,
    });
  }
}
