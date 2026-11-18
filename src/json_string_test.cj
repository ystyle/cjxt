package cjxt

// 入站 JSON 字符串的解析：**必须处理转义**。
//
// 实测：贴一整份人格文件，内容卡在 `为了"像鲸鱼娘"` 的第一个双引号处——
// 值里出现 `"`（JSON 里是 \"），旧实现"找到下一个引号就断"就把它截在那里。
// 截断处看起来完全正常，像"用户只输入了这么多"。

@Test
func jsonString_quotesInsideValueDoNotTruncate() {
    // JSON.stringify 之后：为了\"像鲸鱼娘\"而说话
    let raw = "{\"type\":\"bind\",\"name\":\"chat_input\",\"value\":\"为了\\\"像鲸鱼娘\\\"而说话\"}"
    let v = readBindValue(raw)
    @Expect(v, "为了\"像鲸鱼娘\"而说话")
}

@Test
func jsonString_newlinesAreUnescaped() {
    // 多行输入：换行在 JSON 里是 \n，取出来必须是真换行
    let raw = "{\"value\":\"第一行\\n第二行\\n第三行\"}"
    @Expect(readBindValue(raw), "第一行\n第二行\n第三行")
}

@Test
func jsonString_backslashAndTab() {
    let raw = "{\"value\":\"a\\\\b\\tc\"}"
    @Expect(readBindValue(raw), "a\\b\tc")
}

@Test
func jsonString_unicodeEscape() {
    // \u4f60\u597d = 你好
    let raw = "{\"value\":\"\\u4f60\\u597d\"}"
    @Expect(readBindValue(raw), "你好")
}

@Test
func jsonString_literalNewlineInSourceAlsoWorks() {
    // 防御：真有实现把真换行塞进 JSON 字符串体（不合规），也不该在这里崩或截断
    let raw = "{\"value\":\"a\nb\"}"
    @Expect(readBindValue(raw), "a\nb")
}

@Test
func jsonString_missingValueIsEmpty() {
    @Expect(readBindValue("{\"type\":\"bind\"}"), "")
    @Expect(readBindValue(""), "")
}

@Test
func jsonString_actionParamsHonorEscapes() {
    // action 的 params 走 parseStringPairs，同一套转义规则
    let raw = "{\"type\":\"action\",\"name\":\"character.import\",\"params\":{\"name\":\"小鱼\",\"markdown\":\"说到\\\"人设\\\"就停\"}}"
    let params = readActionParams(raw)
    @Expect(params.get("markdown") ?? "", "说到\"人设\"就停")
    @Expect(params.get("name") ?? "", "小鱼")
}
