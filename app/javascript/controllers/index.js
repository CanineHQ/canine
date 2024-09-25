import { application } from "./application"
import controllers from './**/*_controller.js'
controllers.forEach((controller) => {
  application.register(controller.name, controller.module.default)
})

