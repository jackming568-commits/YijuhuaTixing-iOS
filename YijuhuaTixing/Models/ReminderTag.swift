import Foundation

enum ReminderTag: String, Codable, CaseIterable, Identifiable {
    case businessVisit = "business_visit"
    case meetingCommunication = "meeting_communication"
    case businessTrip = "business_trip"
    case waitingConfirmation = "waiting_confirmation"
    case dailyLife = "daily_life"
    case leisure = "leisure"
    case health = "health"
    case learning = "learning"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .businessVisit:
            return "工作拜访"
        case .meetingCommunication:
            return "会议沟通"
        case .businessTrip:
            return "外地出差"
        case .waitingConfirmation:
            return "等待确认"
        case .dailyLife:
            return "日常生活"
        case .leisure:
            return "娱乐休闲"
        case .health:
            return "健康运动"
        case .learning:
            return "学习成长"
        case .other:
            return "其他"
        }
    }
}

enum ReminderTagClassifier {
    static func classify(title: String, rawInput: String) -> ReminderTag {
        let text = normalized("\(title) \(rawInput)")

        if matchesLeisureTravel(text) { return .leisure }
        if matchesBusinessTrip(text) { return .businessTrip }
        if matchesWaitingConfirmation(text) { return .waitingConfirmation }
        if matchesFamilyDailyLife(text) { return .dailyLife }
        if matchesAny(text, keywords: meetingKeywords) { return .meetingCommunication }
        if matchesAny(text, keywords: businessVisitKeywords) { return .businessVisit }
        if matchesAny(text, keywords: healthKeywords) { return .health }
        if matchesAny(text, keywords: learningKeywords) { return .learning }
        if matchesAny(text, keywords: leisureKeywords) { return .leisure }
        if matchesAny(text, keywords: dailyLifeKeywords) { return .dailyLife }
        return .other
    }

    private static let businessTripKeywords = [
        "出差", "出差拜访", "差旅", "外地", "外地拜访", "异地拜访", "跨城",
        "机场", "航班", "机票", "高铁", "火车票", "动车", "赶飞机", "赶高铁",
        "登机", "值机", "订酒店", "酒店预订", "酒店", "住宿", "行程", "行程单",
        "报销行程", "出差报销", "订机票", "订高铁", "订火车票", "改签", "退票",
        "登机牌", "安检", "托运行李", "收拾行李", "出差材料", "出差申请",
        "出差审批", "接机", "送机", "办理入住", "退房", "会展", "参展",
        "展会", "布展", "撤展", "展位", "展商", "会务", "商务洽谈",
        "客户现场", "现场支持", "驻场", "异地会议", "差旅申请", "差旅审批",
        "酒店发票", "行程报销", "交通报销"
    ]

    private static let waitingConfirmationKeywords = [
        "待确认", "等待确认", "等回复", "等反馈", "等审批", "确认时间", "确定时间",
        "约时间", "看是否", "看看能不能", "看看可以", "看看有没有", "确认一下时间",
        "定时间", "排期", "等客户", "等对方", "等消息", "等通知", "待回复",
        "待反馈", "确认结果", "客户确认", "对方确认", "审批结果", "审批通过",
        "消息回复", "回复后", "确认后", "反馈后", "问进度", "跟进结果",
        "看看结果", "结果出来", "审核结果", "等审核", "等老板确认", "等领导确认",
        "催客户", "催对方", "催一下", "再确认", "二次确认", "待审批",
        "审批中", "过审", "等法务", "等财务", "等运营", "等产品", "等技术",
        "等设计", "等采购", "等供应商", "等渠道", "等联盟", "等合同",
        "等报价", "确认需求", "确认名单", "确认预算", "确认排期",
        "确认方案", "确认合同", "确认报价", "客户反馈", "客户回复",
        "法务确认", "财务确认", "领导审批"
    ]

    private static let meetingKeywords = [
        "开会", "会议", "周会", "例会", "沟通", "电话", "回电", "面试",
        "会前", "会后", "会议室", "参会", "部门会议", "晨会", "站会",
        "复盘会", "评审会", "视频会议", "电话会议", "腾讯会议", "飞书会议",
        "汇报", "讨论", "同步", "碰头", "面谈", "复盘", "面聊",
        "述职", "答辩", "访谈", "需求会", "评审", "路演", "宣讲", "培训会",
        "头脑风暴", "brainstorm", "项目会", "立项会", "启动会", "周例会",
        "月会", "月度会", "季度会", "复盘会议", "需求评审", "技术评审",
        "产品评审", "设计评审", "代码评审", "方案评审", "面试沟通",
        "客户沟通", "需求沟通", "内部沟通", "老板汇报", "领导汇报",
        "客户汇报", "述职汇报", "对齐一下", "拉齐", "拉会", "约会议室",
        "会议纪要", "会纪要", "纪要", "对齐需求", "同步进度"
    ]

    private static let businessVisitKeywords = [
        "拜访", "拜会", "客户", "商务", "合作", "供应商", "渠道", "联盟",
        "报价", "合同", "销售", "跟进", "对接", "约见", "见客户", "拜访客户",
        "外出拜访", "客户拜访", "客户资料", "整理文件", "打印合同", "打印文件",
        "发合同", "签合同", "盖章", "开票", "发票", "对账", "方案", "标书",
        "招标", "投标", "项目资料", "工作文件", "文档", "文件", "sdk", "bd",
        "回访客户", "客户回访", "客户跟进", "发报价", "报价单", "发方案",
        "写方案", "改方案", "提案", "ppt", "PPT", "做PPT", "改PPT", "汇报材料",
        "日报", "周报", "月报", "报表", "数据报表", "发邮件", "回邮件",
        "邮件", "工作邮件", "工单", "需求文档", "项目文档", "合同审批",
        "合同盖章", "寄合同", "寄资料", "交材料", "提交材料", "整理资料",
        "回访", "客户电话", "客户邮件", "客户需求", "客户名单", "客户方案",
        "客户案例", "商务资料", "商务方案", "商务合同", "商务对接",
        "渠道合作", "渠道对接", "供应商合同", "供应商对接", "媒体对接",
        "媒体名单", "媒体邀约", "媒介", "投放", "买量", "预算", "报价单",
        "价格表", "报价邮件", "合同编号", "发票抬头", "回款", "催款",
        "付款", "打款", "收款", "付款申请", "报销", "报销单", "费用报销",
        "采购", "采购单", "招采", "订单", "PO单", "SOW", "OA",
        "审批单", "请假", "请假单", "绩效", "OKR", "KPI",
        "月报", "项目计划", "项目排期", "排期表", "排期确认", "发布计划",
        "发版", "上线", "提测", "验收", "回归测试", "修 bug", "修bug",
        "bug", "联调", "接口联调", "接口对接", "埋点", "数据看板",
        "看数据", "拉数据", "数据分析", "后台", "管理后台", "运营后台",
        "需求池", "产品需求", "PRD", "原型", "测试用例", "发布包",
        "客服工单", "客诉", "售后", "合同模板", "用印", "盖合同章"
    ]

    private static let healthKeywords = [
        "吃药", "喝水", "体检", "看病", "复诊", "挂号", "打针", "健身",
        "瑜伽健身", "瑜伽", "健身房", "锻炼", "跑步", "晨跑", "夜跑",
        "运动", "散步", "拉伸", "游泳", "骑行", "练肩", "练腿", "练胸",
        "复查", "看牙", "牙医", "买药", "早睡", "睡前拉伸", "跳绳",
        "椭圆机", "力量训练", "有氧", "无氧", "普拉提", "打卡运动",
        "测血压", "测血糖", "疫苗", "打疫苗", "按摩", "康复", "理疗",
        "少喝奶茶", "少喝咖啡", "戒烟", "控糖", "减脂", "减肥"
    ]

    private static let learningKeywords = [
        "学习", "读书", "看书", "复习", "考试", "课程", "培训", "作业",
        "听课", "背单词", "写论文", "阅读", "研究", "调研", "刷题",
        "备考", "报名考试", "论文", "读论文", "读文章", "读文档", "技术文档",
        "写笔记", "做笔记", "练英语", "英语", "编程", "预习", "上课",
        "网课", "公开课", "看教程", "教程", "资料整理", "知识库", "复盘笔记",
        "错题", "整理错题", "背书", "背题", "背课文", "背公式", "背资料",
        "学 Kotlin", "学 Swift", "学英语", "学日语", "学车", "驾考", "科目一",
        "科目二", "科目三", "考研", "考公", "考证", "证书"
    ]

    private static let leisureKeywords = [
        "打篮球", "打球", "打台球", "台球", "桌球", "看电影", "看比赛",
        "玩游戏", "游戏", "看剧", "追剧", "看综艺", "ktv", "唱歌", "露营",
        "旅游", "旅行", "度假", "聚餐", "娱乐", "虎扑", "看演出", "演唱会",
        "音乐会", "看展", "展览", "逛街", "桌游", "剧本杀", "密室",
        "约饭", "吃火锅", "喝酒", "喝咖啡", "下午茶", "烧烤", "野餐",
        "钓鱼", "爬山", "徒步", "滑雪", "滑冰", "游乐园", "迪士尼",
        "拍照", "摄影", "打牌", "麻将", "棋牌", "switch", "PS5", "电影票",
        "订票", "抢票", "球赛", "看球", "足球", "篮球赛", "NBA", "CBA",
        "欧冠", "世界杯", "电竞", "王者荣耀", "和平精英", "英雄联盟",
        "LOL", "原神", "Steam", "Xbox", "网吧", "开黑", "上分", "追番",
        "动漫", "动画", "新番", "刷剧", "刷视频", "B站", "b站", "抖音",
        "小红书", "脱口秀", "话剧", "舞台剧", "音乐节", "Livehouse",
        "livehouse", "酒吧", "清吧", "蹦迪", "K歌", "k歌", "喝奶茶",
        "奶茶", "探店", "吃烤肉", "吃日料", "吃自助", "吃小龙虾",
        "吃夜宵", "夜宵", "团建吃饭", "朋友聚会", "同学聚会", "生日聚会",
        "生日派对", "派对", "轰趴", "温泉", "泡温泉", "漂流", "海边",
        "海岛", "民宿", "订民宿", "旅游攻略", "旅行攻略", "做攻略",
        "景点", "景区", "门票", "买门票", "预约门票", "博物馆", "美术馆",
        "动物园", "水族馆", "植物园", "漫展", "车展", "画展", "市集",
        "夜市", "逛夜市", "逛商场", "买衣服", "买鞋", "买包", "美甲",
        "做美甲", "看直播", "直播", "打羽毛球", "打网球", "打乒乓球",
        "羽毛球", "网球", "乒乓球", "保龄球", "飞盘", "卡丁车"
    ]

    private static let dailyLifeKeywords = [
        "外卖", "订餐", "吃饭", "做饭", "买菜", "取快递", "快递", "洗衣服",
        "睡觉", "家里", "妈妈", "爸爸", "房租", "信用卡", "购物", "下班",
        "出门", "倒水", "关门", "关电脑", "备份电脑", "逛公园", "买东西",
        "超市", "菜市场", "做早餐", "做午饭", "做晚饭", "打扫卫生", "打扫",
        "收拾房间", "收拾屋子", "收拾家", "整理房间", "洗碗", "拖地", "扫地",
        "倒垃圾", "清洁", "家务", "缴费", "水电费", "交水电", "搬家", "洗车",
        "取餐", "买日用品", "买水果", "买牛奶", "买纸巾", "买牙膏",
        "买洗发水", "买洗衣液", "买猫粮", "买狗粮", "遛狗", "喂猫", "喂狗",
        "铲屎", "浇花", "收快递", "寄快递", "退货", "换货", "拿快递",
        "修电脑", "修手机", "修水管", "修空调", "保洁", "做核酸", "办证",
        "身份证", "护照", "银行卡", "还信用卡", "交房租", "交物业费",
        "物业费", "停车费", "加油", "充电", "充话费", "剪头发", "理发",
        "晒被子", "换床单", "洗床单", "收衣服", "晾衣服", "叠衣服",
        "整理衣柜", "整理厨房", "整理冰箱", "清理冰箱", "清理垃圾",
        "擦桌子", "擦窗户", "消毒", "除尘", "收纳", "整理收纳",
        "换灯泡", "开窗通风", "通风", "关窗", "关空调", "关燃气",
        "关煤气", "关水龙头", "买米", "买面", "买鸡蛋", "买肉",
        "买鱼", "买饮料", "买零食", "买早餐", "买午饭", "买晚饭",
        "煮饭", "煲汤", "蒸米饭", "洗菜", "切菜", "备菜",
        "取件", "寄件", "拿外卖", "取外卖", "收外卖", "退快递",
        "拿包裹", "包裹", "快递柜", "菜鸟驿站", "驿站",
        "交电费", "交水费", "交燃气费", "燃气费", "网费", "宽带费",
        "交宽带", "还花呗", "还借呗", "还贷款", "还房贷", "还车贷",
        "挪车", "缴停车费", "年检", "车检", "保养车", "车辆保养",
        "充电桩", "换机油", "办身份证", "换身份证", "办护照",
        "办银行卡", "取钱", "存钱", "转账", "去银行", "社保",
        "公积金", "医保", "社区登记", "接孩子", "送孩子", "接娃",
        "送娃", "家长会", "买礼物", "生日礼物", "洗头", "护肤",
        "敷面膜", "买护肤品", "剪指甲", "配眼镜", "洗澡"
    ]

    private static func matchesBusinessTrip(_ text: String) -> Bool {
        matchesAny(text, keywords: businessTripKeywords)
    }

    private static func matchesLeisureTravel(_ text: String) -> Bool {
        matchesAny(text, keywords: leisureTravelKeywords)
    }

    private static func matchesWaitingConfirmation(_ text: String) -> Bool {
        if matchesAny(text, keywords: waitingConfirmationKeywords) {
            return true
        }
        return (text.contains("约") || text.contains("约下")) && text.contains("时间")
    }

    private static func matchesFamilyDailyLife(_ text: String) -> Bool {
        matchesAny(text, keywords: familyDailyLifeKeywords)
    }

    private static func matchesAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains(normalized($0)) }
    }

    private static let familyDailyLifeKeywords = [
        "妈妈", "爸爸", "爸妈", "父母", "家人", "家里", "老婆", "老公",
        "孩子", "儿子", "女儿", "爷爷", "奶奶", "外公", "外婆",
        "家长会", "接孩子", "送孩子", "接娃", "送娃"
    ]

    private static let leisureTravelKeywords = [
        "旅游", "旅行", "度假", "民宿", "旅游攻略", "旅行攻略", "做攻略",
        "景点", "景区", "门票", "游乐园", "迪士尼", "温泉", "海边", "海岛",
        "博物馆", "美术馆", "动物园", "水族馆"
    ]

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "zh-Hans-CN"))
            .lowercased()
    }
}
