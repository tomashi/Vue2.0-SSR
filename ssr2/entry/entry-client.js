/* entry-client.js */
import { createApp } from '../src/main'


const app = createApp()

// 绑定app根元素
window.onload = function() {
       app.$mount('#app')
}
