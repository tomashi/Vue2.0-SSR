##前言
这篇教程主要通过3个项目，一步一步将ssr的原理及实现过程展现出来，供不知道如何开发vue服务端渲染的同学学习参考，另外也加深下自己的认识，文章有纰漏的地方，请大家多多指出。

##技术栈
框架是vue(版本：2.5.16)，node上使用express框架，通过webpack和gulp进行打包操作

##我们为什么要使用服务的渲染？
```
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <title>Document</title>
</head>

<body>

    <div id="app"></div>
    <script type=text/javascript src=./static/js/bundle.js></script>
    
</body>

</html>
```
上面是一个典型的vue应用，从返回的html页面可以看到，页面中只有app容器和一个js包的加载地址
并且无论你请求的路由是那种
```
localhost:8080/home
```
```
localhost:8080/animal
```
```
localhost:8080/people
```
都只会返回同样的信息：
```
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <title>Document</title>
</head>

<body>

    <div id="app"></div>
    <script type=text/javascript src=./static/js/bundle.js></script>
    
</body>

</html>
```
虽然我们知道js会根据访问路由渲染出我们看到的信息，但是对于爬虫来说，它仅仅获取到了2个标签，而没有页面真实呈现内容的信息

这样就会有一个明显的缺点：**缺少SEO**

服务端渲染正是用来解决这个问题，当你请求不同路由时
```
localhost:8080/home
```
会返回给你相应的结果：
```
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <title>Document</title>
</head>

<body>

    <div id="app">
        <div>this is home page</div>
    </div>
    <script type=text/javascript src=./static/js/bundle.js></script>
    
</body>

</html>
```
## 项目一
> 在项目一中，我们创建一个最原始的SSR项目，便于理解SSR的原理

首先创建一个文件夹ssr，然后进入ssr
```
$ cd ssr
```
```
$ npm init
```
创建server.js文件
下载相应插件
```
$ npm i vue
$ npm i express
$ npm i vue-server-renderer
```
server.js文件的内容为：
```
/* server.js */
const Vue = require('vue')
const express = require('express')()
const renderer = require('vue-server-renderer').createRenderer()


// 创建Vue实例
const app= new Vue({
    template: '<div>hello world</div>'
})


// 响应路由请求
express.get('/', (req, res) => {
    renderer.renderToString(app, (err, html) => {
        if (err) { return res.state(500).end('运行时错误') }
        res.send(`
            <!DOCTYPE html>
            <html lang="en">
                <head>
                    <meta charset="UTF-8">
                    <title>Vue2.0 SSR渲染页面</title>
                </head>
                <body>
                    ${html}
                </body>
            </html>
        `)
    })
})


// 服务器监听地址
express.listen(8080, () => {
    console.log('服务器已启动！')
})
```
创建Vue实例只需要模板属性即可

ssr文件夹目录结构：
```
/* ssr目录结构 */
| - node_modules
  - package.json
  - package-lock.json
  - server.js
```
启动服务：
```
$ node server
```
打开浏览器，地址栏输入：
```
localhost:8080
```
我们可以看到，页面加载成功：

![localhost:8080](https://upload-images.jianshu.io/upload_images/8958489-f86f0ef36808e53b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

并且打开谷歌浏览器的开发者工具，查看Network => Doc => localhost => Response

![localhost](https://upload-images.jianshu.io/upload_images/8958489-04d18c03faba6f0e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们可以看到Vue实例中的模板已经被渲染到了html页面并返回到了客户端

服务端渲染的核心就在于：**通过vue-server-renderer插件的renderToString()方法，将Vue实例转换为字符串插入到html文件**

## 项目二
> 我们在项目一的基础上进行改造，加入路由功能，并且划分清服务端与客户端各自所负责的范围

通过项目一，我们知道了输入指定路由，会从服务端返回相关路由拥有seo内容的页面。那加入了路由后，我们每切换一个页面，是不是仍然像项目一那样请求服务器，然后服务器渲染出对应的页面返回给我们呢？
答案当然是否定的，不要被项目一的成功冲昏了头脑，如果真的那样做了，我们实际上就倒退回了web1.0的时代，那个时代每次进入新的路由就会重新请求服务器，造成大量的资源浪费

**我们使用服务端渲染是为了弥补单页面应用SEO能力不足的问题
因此，实际上我们第一次在浏览器地址栏输入url，并且得到返回页面之后，所有的操作仍然是单页面应用在控制。我们所做的服务端渲染，只是在平时返回的单页面应用html上增加了对应路由的页面信息，好让爬虫获取到而已**

明白了这一点，我就可以将项目一分为二，也就是分为服务端渲染和客户端渲染。服务端渲染就是项目一所做的，根据vue实例获取对应路由的seo信息，然后添加到返回的单页面应用html上；客户端渲染就是平时我们所熟悉的单页面应用，

##公共部分
无论是服务端渲染还是客户端渲染，他们都需要一个vue实例，因此我们先从这里说起

下载相应插件
```
{
  "name": "ssr",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "server": "webpack --config ./webpack/webpack.server.js",
    "client": "webpack --config ./webpack/webpack.client.js"
  },
  "author": "",
  "license": "ISC",
  "dependencies": {
    "axios": "^0.16.0",
    "babel": "^6.23.0",
    "babel-plugin-transform-runtime": "^6.23.0",
    "babel-polyfill": "^6.26.0",
    "babel-preset-env": "^1.7.0",
    "body-parser": "^1.18.3",
    "compression": "^1.7.2",
    "express": "^4.15.4",
    "express-http-proxy": "^1.2.0",
    "gulp": "^3.9.1",
    "gulp-shell": "^0.6.5",
    "http-proxy-middleware": "^0.18.0",
    "less": "^3.0.4",
    "less-loader": "^4.1.0",
    "shell": "^0.5.0",
    "superagent": "^3.8.3",
    "vue": "^2.2.2",
    "vue-meta": "^1.5.0",
    "vue-router": "^2.2.0",
    "vue-server-renderer": "^2.2.2",
    "vue-ssr-webpack-plugin": "^3.0.0",
    "vuex": "^2.2.1",
    "vuex-router-sync": "^4.2.0"
  },
  "devDependencies": {
    "babel-core": "^6.26.3",
    "babel-loader": "^6.4.1",
    "babel-preset-es2015": "^6.24.1",
    "css-loader": "^0.28.4",
    "style-loader": "^0.18.2",
    "vue-loader": "^11.1.4",
    "vue-template-compiler": "^2.2.4",
    "webpack": "^2.7.0"
  }
}
```
```
$ npm i 
```
插件很多，不一一列举了，直接复制 package.json 文件内容，安装即可

ssr文件夹目录结构：
```
/* ssr目录结构 */
| - node_modules
| - src
    | - routes
          - animal.vue
          - home.vue
          - people.vue
      - App.vue
      - main.js
      - route.js
  - package.json
  - package-lock.json
  - server.js
```

创建src文件夹，用于存放vue实例相关的文件

main.js作为创建vue实例的引用文件：
```
/* main.js */
import Vue from 'vue'
import createRouter from './route.js'
import App from './App.vue'


// 导出一个工厂函数，用于创建新的vue实例
export function createApp() {
    const router = createRouter()
    const app = new Vue({
        router,
        render: h => h(App)
    })

    return app
}
```
main.js文件导出的是一个工厂函数，使用这个工厂函数会创建一个新的vue实例，这样可以隔离开各个客户端的请求。每次客户端的请求，都会创建一个新的vue实例，接着对这个实例进行路由渲染，然后返回给客户端

route.js作为vue实例创建路由的引用文件：

```
/* route.js */
import Vue from 'vue'
import VueRouter from 'vue-router'

Vue.use(VueRouter)

export default function createRouter() {
    let router = new VueRouter({
        // 要记得增加mode属性，因为#后面的内容不会发送至服务器，服务器不知道请求的是哪一个路由
        mode: 'history',
        routes: [
            {
                alias: '/',
                path: '/home',
                component: require('./routes/home.vue')
            },
            {
                path: '/animal',
                component: require('./routes/animal.vue')
            },
            {
                path: '/people',
                component: require('./routes/people.vue')
            }
        ]
    })

    return router
}
```
这里的路由配置要记得加上 mode: 'history' 这个配置选项，因为默认的路由方式是通过#后面的数据变化来实现路由跳转的。而#后面的数据是不会发送给服务器的，因此服务端收到的永远是根文件index.html的资源请求，这样就无法根据路由信息来进行服务端渲染了

App.vue作为vue实例的根组件：

```
<!-- App.vue -->
<template>
      <div>
            <h2>欢迎来到SSR渲染页面</h2>
            <router-view></router-view>
      </div>
</template>


<script>
export default {
      mounted() {

      }
}
</script>


<style>

</style>
```

创建routes文件夹，存放vue实例的路由文件，里面的animal.vue、home.vue、people.vue大同小异

home.vue文件：

```
<!-- home.vue -->
<template>
      <div>
            home
      </div>
</template>


<script>
export default {
      mounted() {

      }
}
</script>


<style scoped>

</style>
```
##服务端渲染部分
在ssr文件夹下创建entry入口文件夹，作为webpack入口文件的存放位置
在entry文件夹里面创建entry-server.js服务端入口文件
在ssr文件夹下创建webpack文件夹，作为webpack配置文件的存放位置
在webpack文件夹中创建webpacl.server.js服务端配置文件
在ssr文件夹下创建dist文件夹，作为打包文件的存放位置

ssr文件夹目录结构：
```
/* ssr目录结构 */
| - dist
| - node_modules
| - entry
    - entry-server.js
| - src
    | - routes
          - animal.vue
          - home.vue
          - people.vue
      - App.vue
      - main.js
      - route.js
| - webpack
    - webpack.server.js
  - .babelrc
  - package.json
  - package-lock.json
  - server.js
```

创建.babelrc文件夹用于配置babel
```
{
      "presets": [
            "babel-preset-env"
      ],
      "plugins": [
            "transform-runtime"
      ]
}
```

更改server.js文件为：
```
/* server.js */
const express = require('express')()
const renderer = require('vue-server-renderer').createRenderer()
const createApp = require('./dist/bundle.server.js')['default']

// 响应路由请求
express.get('*', (req, res) => {
    const context = { url: req.url }

    // 创建vue实例，传入请求路由信息
    createApp(context).then(app => {
        renderer.renderToString(app, (err, html) => {
            if (err) { return res.state(500).end('运行时错误') }
            res.send(`
                <!DOCTYPE html>
                <html lang="en">
                    <head>
                        <meta charset="UTF-8">
                        <title>Vue2.0 SSR渲染页面</title>
                    </head>
                    <body>
                        ${html}
                    </body>
                </html>
            `)
        })
    }, err => {
        if(err.code === 404) { res.status(404).end('所请求的页面不存在') }
    })
})


// 服务器监听地址
express.listen(8080, () => {
    console.log('服务器已启动！')
})
```
监听到路由请求后，将路由信息传入并创建一个新的vue实例。因为创建vue实例涉及到很多步骤，所以这里是一个promise回调函数。当实例创建完成后，将返回的实例信息传入渲染器中进行处理，处理结束后得到的字符串放入html中返回给客户端

entry-server.js：
```
/* entry-server.js */
import { createApp } from '../src/main'

export default context => {
    return new Promise((resolve, reject) => {
        const app = createApp()

        // 更改路由
        app.$router.push(context.url)

        // 获取相应路由下的组件
        const matchedComponents = app.$router.getMatchedComponents()

        // 如果没有组件，说明该路由不存在，报错404
        if (!matchedComponents.length) { return reject({ code: 404 }) }

        resolve(app)
    })

}
```
上面说过，因为这里会有很多处理步骤，所以为了保证同步，使用promise函数来处理。当调用这个函数时，会创建一个新的vue实例，然后通过路由的push()方法，来更改实例的路由状态。更改完成后获取到该路由下将加载的组件，根据所得组件的长度来判断该路由页面是否存在

webpack.server配置：
```
/* webpack.server.js */
const path = require('path');
const projectRoot = path.resolve(__dirname, '..');


module.exports = {
    // 此处告知 server bundle 使用 Node 风格导出模块(Node-style exports)
    target: 'node',
    entry: ['babel-polyfill', path.join(projectRoot, 'entry/entry-server.js')],
    output: {
        libraryTarget: 'commonjs2',
        path: path.join(projectRoot, 'dist'),
        filename: 'bundle.server.js',
    },
    module: {
        rules: [{
                test: /\.vue$/,
                loader: 'vue-loader',
            },
            {
                test: /\.js$/,
                loader: 'babel-loader',
                include: projectRoot,
                exclude: /node_modules/,
                options: {
                    presets: ['es2015']
                }
            },
            {
                test: /\.less$/,
                loader: "style-loader!css-loader!less-loader"
            }
        ]
    },
    plugins: [],
    resolve: {
        alias: {
            'vue$': 'vue/dist/vue.runtime.esm.js'
        }
    }
}
```

打包文件并开启服务器：
```
$ npm run server
$ node server
```

浏览器输入
```
localhost:8080
```

可以看到：

![/](https://upload-images.jianshu.io/upload_images/8958489-7227e986041ae5ec.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们成功的进入页面，并且页面上加载这默认路由的对应信息，我们切换至 /animal 试一试：

![animal](https://upload-images.jianshu.io/upload_images/8958489-8aac2b281321491a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

并且打开谷歌浏览器的开发者工具，查看Network => Doc => animal=> Response

![animal](https://upload-images.jianshu.io/upload_images/8958489-fef39add069f53dc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们可以看到，服务端返回的html文件中，已经有了对应页面的SEO信息了

那么我们已经成功了吗？
当然，还没有，因为现在返回过来的只是一个页面的对应信息，并且如果切换至另一个路由就会重新向服务端发起请求，获取页面，还处于web1.0时代。这是因为我们的单页面应用没有加载导致的，下面我们就来配置单页面应用，并将它引入到返回的html页面当中

##客户端渲染部分
在entry文件夹中创建entry-client.js客户端入口文件
在webpack文件夹中创建webpacl.client.js客户端配置文件

entry-client.js：
```
/* entry-client.js */
import { createApp } from '../src/main'


const app = createApp()

// 绑定app根元素
window.onload = function() {
       app.$mount('#app')
}
```
这里比较简单，提到一个小技巧，就是要在window加载完成后再绑定app根元素启动应用，这个要结合服务端返回的html页面一起看

更改server.js文件：
```
/* server.js */
const exp = require('express')
const express = exp()
const renderer = require('vue-server-renderer').createRenderer()
const createApp = require('./dist/bundle.server.js')['default']


// 设置静态文件目录
express.use('/', exp.static(__dirname + '/dist'))


const clientBundleFileUrl = '/bundle.client.js'


// 响应路由请求
express.get('*', (req, res) => {
    const context = { url: req.url }

    // 创建vue实例，传入请求路由信息
    createApp(context).then(app => {
        renderer.renderToString(app, (err, html) => {
            if (err) { return res.state(500).end('运行时错误') }
            res.send(`
                <!DOCTYPE html>
                <html lang="en">
                    <head>
                        <meta charset="UTF-8">
                        <title>Vue2.0 SSR渲染页面</title>
                        <script src="${clientBundleFileUrl}"></script>
                    </head>
                    <body>
                        <div id="app">${html}</div>
                    </body>
                </html>
            `)
        })
    }, err => {
        if(err.code === 404) { res.status(404).end('所请求的页面不存在') }
    })
})


// 服务器监听地址
express.listen(8080, () => {
    console.log('服务器已启动！')
})
```
这里的改动，主要在于head下面增加了一个脚本标签，用于引入我们的单页面应用，这点和平时我们使用单页面应用的方法一样

**需要特别注意的是**：一般script标签我们都会放置在body标签内的最下方，来防止长时间的白屏，但是如果这里也这样做，会发现进入页面后会看到大量没有样式的SEO内容，短暂的延迟后，由于script文件的加载完毕，会闪屏至正常的有样式的页面，这样用户的体验非常不好。因此我们将脚本标签放在head中先加载，并且设置window的onload事件，当body的内容加载完毕后再触发脚本，虽然有了白屏时间，但是时间短暂，用户体验相比之下会更好

webpack.client.js :
```
/* webpack.client.js */
const path = require('path');
const projectRoot = path.resolve(__dirname, '..');


module.exports = {
      entry: ['babel-polyfill', path.join(projectRoot, 'entry/entry-client.js')],
      output: {
            path: path.join(projectRoot, 'dist'),
            filename: 'bundle.client.js',
      },
      module: {
            rules: [{
                        test: /\.vue$/,
                        loader: 'vue-loader'
                  },
                  {
                        test: /\.js$/,
                        loader: 'babel-loader',
                        include: projectRoot,
                        exclude: /node_modules/,
                        options: {
                              presets: ['es2015']
                        }
                  }
            ]
      },
      plugins: [],
      resolve: {
            alias: {
                  'vue$': 'vue/dist/vue.runtime.esm.js'
            }
      }
};
```
大同小异

App.vue改为：
```
<!-- App.vue -->
<template>
      <div>
            <h2>欢迎来到SSR渲染页面</h2>
            <router-link to="/home">home</router-link>
            <router-link to="/animal">animal</router-link>
            <router-link to="/people">people</router-link>
            <router-view></router-view>
      </div>
</template>


<script>
export default {
      mounted() {

      }
}
</script>


<style>

</style>
```
增加了3个路由标签，用于测试

打包文件并开启服务器
```
$ npm run server
$ npm run client
$ node server
```

浏览器输入
```
localhost:8080/people
```

可以看到：

![people](https://upload-images.jianshu.io/upload_images/8958489-c0c95cecc6143330.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

点击home链接：

![home](https://upload-images.jianshu.io/upload_images/8958489-4254a4b26b996ef0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

切换到home内容，并且浏览器没有再次请求服务器，一切都在浏览器本地完成，打开谷歌浏览器的开发者工具，查看Network => Doc => home=> Response

![home](https://upload-images.jianshu.io/upload_images/8958489-cad2645c750876f4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

可以看到，虽然我们已经进入了people页面，但是html页面仍然是最初进入的home的SEO信息，这说明我们正在使用单页面应用，没有再经过服务器端的渲染了

至此，项目二结束，我们请求任意路由页面，可以得到相关的SEO信息，并且返回给我们的是一个单页面应用，我们可以在上面高性能的切换路由或者进行别的操作，而不必浪费大量的资源再次请求服务器了

##项目三
> 经过项目二，我的项目已经初具规模，但是还缺少了一个重要的东西。聪明的你可能已经想到了，我们现在虽然能够得到SEO信息，但是都是我们写死的静态页面的信息，动态从服务器请求的数据并没有获取到，项目三将完成这一重要功能，实现完全的服务端渲染

我们将项目二的文件夹复制一份，在其基础上进行项目三的改造

##思路
话分两头说，这里我们也是分服务端和客户端两边来说，先说说服务端
服务端需要在渲染阶段前获取到相关的请求信息，然后将信息写入到vue实例当中，再通过vue渲染器渲染成字符串，插入到html文件中

entry.server.js：
```
/* entry-server.js */
import { createApp } from '../src/main'

export default context => {
    return new Promise((resolve, reject) => {
        const app = createApp()

        // 更改路由
        app.$router.push(context.url)

        // 获取相应路由下的组件
        const matchedComponents = app.$router.getMatchedComponents()

        // 如果没有组件，说明该路由不存在，报错404
        if (!matchedComponents.length) { return reject({ code: 404 }) }

        // 遍历路由下所以的组件，如果有需要服务端渲染的请求，则进行请求
        Promise.all(matchedComponents.map(component => {
            if (component.serverRequest) {
                return component.serverRequest(app.$store)
            }
        })).then(() => {
            resolve(app)
        }).catch(reject)
    })

}
```
我们增加了一个Promise.all函数，将异步的请求变为同步状态，当我们指定的任务执行完毕后，vue实例才算是创建完成
我们遍历请求路由下的组件，通过是否有serverRequest这个函数来判断是否需要服务端请求数据，如果需要则执行这个函数，并传入一个store参数，store是vue的Vuex的状态管理参数，下面是它的代码：
```
/* store.js */
import Vue from 'vue'
import Vuex from 'vuex'
import axios from 'axios'

Vue.use(Vuex)

export default function createStore() {
      let store =  new Vuex.Store({
            state: {
                  homeInfo: ''
            },
            actions: {
                  getHomeInfo({ commit }) {
                        return axios.get('http://localhost:8080/api/getHomeInfo').then((res) => {
                              commit('setHomeInfo', res.data)
                        })
                  }
            },
            mutations: {
                  setHomeInfo(state, res) {
                        state.homeInfo = res
                  }
            }
      })

      return store
}
```
通过Vue的axios来发起请求

改造后的main.js：
```
/* main.js */
import Vue from 'vue'
import createRouter from './route.js'
import App from './App.vue'
import createStore from './store'


// 导出一个工厂函数，用于创建新的vue实例
export function createApp() {
    const router = createRouter()
    const store = createStore()
    const app = new Vue({
        router,
        store,
        render: h => h(App)
    })

    return app
}
```
引入store进入vue实例

改造后的server.js：
```
/* server.js */
const exp = require('express')
const express = exp()
const renderer = require('vue-server-renderer').createRenderer()
const createApp = require('./dist/bundle.server.js')['default']


// 设置静态文件目录
express.use('/', exp.static(__dirname + '/dist'))


// 客户端打包地址
const clientBundleFileUrl = '/bundle.client.js'


// getHomeInfo请求
express.get('/api/getHomeInfo', (req, res) => {
    res.send('SSR发送请求')
})


// 响应路由请求
express.get('*', (req, res) => {
    const context = { url: req.url }

    // 创建vue实例，传入请求路由信息
    createApp(context).then(app => {
        renderer.renderToString(app, (err, html) => {
            if (err) { return res.state(500).end('运行时错误') }
            res.send(`
                <!DOCTYPE html>
                <html lang="en">
                    <head>
                        <meta charset="UTF-8">
                        <title>Vue2.0 SSR渲染页面</title>
                        <script src="${clientBundleFileUrl}"></script>
                    </head>
                    <body>
                        <div id="app">${html}</div>
                    </body>
                </html>
            `)
        })
    }, err => {
        if(err.code === 404) { res.status(404).end('所请求的页面不存在') }
    })
})


// 服务器监听地址
express.listen(8080, () => {
    console.log('服务器已启动！')
})
```
增加了一个处理 '/api/getHomeInfo' 请求的函数

改造后的home.vue：
```
<!-- home.vue -->
<template>
  <div>
    home
    <div>{{ homeInfo }}</div>
</div>
</template>


<script>
    export default {
        serverRequest(store) {
            return store.dispatch('getHomeInfo')
        },
        mounted() {
            
        },
        computed: {
            homeInfo() {
              return this.$store.state.homeInfo
          }
      }
  }
</script>


<style scoped>

</style>
```
可以看到，这里我们写了一个serverRequest函数，用于告诉服务端，让服务端来请求数据，然后通过监听store中的数据来获取参数

看到这里，大家可能有疑问，为什么要用store来发起请求呢？通过项目二我们知道，服务端和客户端是两个vue实例各自进行自己的渲染，然后拼接在一起的，通过serverRequest发出的请求只有服务端的vue实例可以拿到这个store数据，而客户端的vue实例是拿不到的，可以看下图：

![home](https://upload-images.jianshu.io/upload_images/8958489-f364db7aac9926e4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

请求路由返回的html文件中，明明是有 'SSR发送请求的' 字样的，说明我们的服务端请求并且渲染到html文件上已经成功了，但是页面上为什么不显示呢？
```
<template>
  <div>
    home
    <div>{{ homeInfo }}</div>
</div>
</template>
```
这是因为客户端的vue实例脚本加载成功后，{{ homeInfo }} 被客户端的homeInfo属性覆盖，而客户端的homeInfo是没有值的，是个空的属性，因此不显示

那么怎么解决这个问题呢？
普通的办法就是像一般的单页面应用一样，加载到这个组件时，去请求下数据，然后将数据渲染到页面上，对于单页面这是正确的办法，但是对于我们服务端渲染的应用则不然。我们在服务器上已经请求过一次了，再请求一次会浪费多余的资源，所以我们就用到了vue的状态管理

你可能会问了，你上面不才说服务端和客户端是两个不同的vue实例，store是不相通的吗？没错，下面我们就通过一个 \_\_INITIAL_STATE\_\_ 属性来架起一座连接服务端与客户端之间的桥梁，让他们的数据相互贯通

##\_\_INITIAL_STATE\_\_ 属性
我们先看到server.js文件中有这么一句话：
```
// 响应路由请求
express.get('*', (req, res) => {
    const context = { url: req.url }

    // 创建vue实例，传入请求路由信息
    createApp(context).then(app => {
        renderer.renderToString(app, (err, html) => {
            if (err) { return res.state(500).end('运行时错误') }
            res.send(`
                <!DOCTYPE html>
```
收到客户端对服务器发出的任意路由信息，然后将路由信息放入context对象中，传给vue实例创建器用以创建vue实例，我们借用的正是context属性

下面我们对entry.server.js文件进行改造：
```
/* entry-server.js */
import { createApp } from '../src/main'

export default context => {
    return new Promise((resolve, reject) => {
        const app = createApp()

        // 更改路由
        app.$router.push(context.url)

        // 获取相应路由下的组件
        const matchedComponents = app.$router.getMatchedComponents()

        // 如果没有组件，说明该路由不存在，报错404
        if (!matchedComponents.length) { return reject({ code: 404 }) }

        // 遍历路由下所以的组件，如果有需要服务端渲染的请求，则进行请求
        Promise.all(matchedComponents.map(component => {
            if (component.serverRequest) {
                return component.serverRequest(app.$store)
            }
        })).then(() => {
            context.state = app.$store.state
            resolve(app)
        }).catch(reject)
    })

}
```
这里的context对象，就是刚才我们传入的那个context对象，我们在将路由匹配下的组件的serverRequest函数执行一圈后，服务端vue实例的store已经改变了自己的状态，里面的state属性也不再是默认为空的状态了，此时我们将这个已经收获满满果实的state属性赋值给context对象，然后改造server.js文件：
```
/* server.js */
const exp = require('express')
const express = exp()
const renderer = require('vue-server-renderer').createRenderer()
const createApp = require('./dist/bundle.server.js')['default']


// 设置静态文件目录
express.use('/', exp.static(__dirname + '/dist'))


// 客户端打包地址
const clientBundleFileUrl = '/bundle.client.js'


// getHomeInfo请求
express.get('/api/getHomeInfo', (req, res) => {
    res.send('SSR发送请求')
})


// 响应路由请求
express.get('*', (req, res) => {
    const context = { url: req.url }

    // 创建vue实例，传入请求路由信息
    createApp(context).then(app => {
        let state = JSON.stringify(context.state)

        renderer.renderToString(app, (err, html) => {
            if (err) { return res.state(500).end('运行时错误') }
            res.send(`
                <!DOCTYPE html>
                <html lang="en">
                    <head>
                        <meta charset="UTF-8">
                        <title>Vue2.0 SSR渲染页面</title>
                        <script>window.__INITIAL_STATE__ = ${state}</script>
                        <script src="${clientBundleFileUrl}"></script>
                    </head>
                    <body>
                        <div id="app">${html}</div>
                    </body>
                </html>
            `)
        })
    }, err => {
        if(err.code === 404) { res.status(404).end('所请求的页面不存在') }
    })
})


// 服务器监听地址
express.listen(8080, () => {
    console.log('服务器已启动！')
})
```
我们创建新属性state，并将context.state属性转为字符串赋值给它，然后再head标签下，客户端vue脚本前，增加一个script标签，内容是，创建一个全局对象，值是state的值，这样我们就成功了一半，已经将服务端请求得出的结果传给了客户端，我们可以看下浏览器接受html文件的图片：

![localhost](https://upload-images.jianshu.io/upload_images/8958489-9b91723c22393330.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

下面，我们将完成桥梁的最后一步，将\_\_INITIAL_STATE\_\_属性同步到客户端vue实例的store上去

改造entry.client.js：
```
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
```
使用store的replaceState方法，同步服务端的store到客户端的store，我们看下浏览器的情况：

![localhost](https://upload-images.jianshu.io/upload_images/8958489-f911696408cbe5bd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
是的，很嗨！我们不光服务器端的seo有了请求的内容，并且通过同步状态，不用花费多的请求，就让客户端也获取了相应的数据，至此项目三结束，我们已经实现了完整的服务端渲染项目

撒花=*★,°*:.☆\(￣▽￣)/$:*.°★* 。 

##补充
正真的项目开发中，光有上面的实现内容，只能算是一个会动的骨架（有点吓人），实际上还有很多自定义的内容可以加上去，比方说vue的vue-meta来管理head的seo相关标签，以及通过gulp、webpack、nodemon之类的进一步的完善自动化SSR开发构建环境等等，等待着大家去探索

##结语
这篇文章用了端午三天时间完成（第一次写文章是这样的...）
关于ssr以及前端别的很多内容其实早就想写了，但是一坐到电脑面前就不知所措，这回放假才鼓起了勇气，还是很开心的，加深了我对ssr以及相关知识的认识
希望能够帮助到刚接触vue服务端渲染像我当时一样不知所措的人

##代码下载地址
https://github.com/tomashi/Vue2.0-SSR

##参考
https://github.com/zyl1314/vue-ssr-demo/issues/2
