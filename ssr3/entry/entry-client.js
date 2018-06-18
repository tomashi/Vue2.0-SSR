/* entry-client.js */
import { createApp } from '../src/main'


// 同步服务端信息
if (window.__INITIAL_STATE__) {
      store.replaceState(window.__INITIAL_STATE__)
}


const app = createApp()

// 绑定app根元素
window.onload = function() {
       app.$mount('#app')
}
