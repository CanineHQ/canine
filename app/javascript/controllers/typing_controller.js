import Typed from 'typed.js';
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typing"]

  connect() {
    const words = JSON.parse(this.element.dataset.typingWords || '[]');
    const colors = JSON.parse(this.element.dataset.typingColors || '[]');

    const strings = words.map(function(word, i) {
      var color = colors[i] || colors[0] || '#ffffff';
      return '<b style="color: ' + color + '">' + word + '</b>';
    });

    new Typed(this.typingTarget, {
      strings,
      typeSpeed: 50,
      loop: true,
    });
  }
}
