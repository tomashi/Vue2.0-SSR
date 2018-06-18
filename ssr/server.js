/* server.js */
const Vue = require('vue')
const express = require('express')()
const renderer = require('vue-server-renderer').createRenderer()


// 创建Vue实例
const app = new Vue({
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