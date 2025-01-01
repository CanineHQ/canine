import { application } from "./application"
import TextareaAutogrow from 'stimulus-textarea-autogrow'

import controllers from './**/*_controller.js'

application.register('textarea-autogrow', TextareaAutogrow)
controllers.forEach((controller) => {
  application.register(controller.name, controller.module.default)
})

