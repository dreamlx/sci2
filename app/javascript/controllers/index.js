// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "./application"

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

export { application }
