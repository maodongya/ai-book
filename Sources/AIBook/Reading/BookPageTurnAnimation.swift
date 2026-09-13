import AppKit
import SceneKit
import SwiftUI

/// 翻页方向：向前翻下一 spread / 向后翻上一 spread。
enum BookPageTurnDirection { // 枚举两种翻页方向
    case forward // 向前翻页
    case backward // 向后翻页
}

/// 翻页进度曲线：smoothstep，用于 mesh 与时间轴 easing。
enum BookPageTurnEasing { // 无实例工具
    /// 将线性进度 [0,1] 映射为 smoothstep 曲线。
    static func transform(_ progress: CGFloat) -> CGFloat {
        let t = min(max(progress, 0), 1) // 钳制到合法区间
        return t * t * (3 - 2 * t) // 返回 smoothstep 值
    }

    /// 在 edge0…edge1 区间内对 x 做 smoothstep。
    static func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1) // 归一化并钳制
        return t * t * (3 - 2 * t) // 返回 smoothstep 值
    }
}

/// 书页 mesh 卷曲：单张可展曲面，绕书脊铰链落下，避免圆柱顶撕裂。
enum BookPageMeshDeformer { // 无实例 deformer
    /// 翻页进度 0...1 映射到网格姿态。
    static func pose(
        u: CGFloat,
        v: CGFloat,
        progress: CGFloat,
        direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        height: CGFloat,
        pageOriginX: CGFloat
    ) -> SIMD3<Float> {
        let t = BookPageTurnEasing.transform(progress)  // 时间轴也走同一条曲线
        let uu = min(max(u, 0), 1)  // 横向参数
        let vv = min(max(v, 0), 1)  // 纵向参数
        let restX: CGFloat  // 平铺时的 x
        let spineX: CGFloat  // 铰链，绕它转
        switch direction {  // 向前铰链在左，向后在右
        case .forward:  // 下一摊，页从右往左合
            spineX = pageOriginX  // 书脊在左缘
            restX = pageOriginX + uu * pageWidth  // u=0 靠脊，u=1 靠外沿
        case .backward:  // 上一摊，页从左往右合
            spineX = pageOriginX + pageWidth  // 铰链在右缘
            restX = pageOriginX + pageWidth - uu * pageWidth  // u=0 靠脊（右），u=1 靠左沿
        }
        let restY = vv * height  // 底=0 顶=height

        let flatten = BookPageTurnEasing.smoothstep(0.64, 1, t)  // 后段才压平绕脊翻
        let curlAmount = t * (1 - flatten)  // 前段卷角，后段交给铰链

        let curled = cornerCurl(  // 先卷角得到 xyz
            curlAmount: curlAmount,
            direction: direction,
            pageWidth: pageWidth,
            height: height,
            pageOriginX: pageOriginX,
            restX: restX,
            restY: restY
        )

        let hinge = CGFloat.pi * flatten  // 0 到 180°，整页翻过去
        let relX = curled.x - spineX  // 相对书脊
        let hingedX = spineX + relX * cos(hinge) - curled.z * sin(hinge)  // 绕 Y 旋
        let hingedZ = relX * sin(hinge) + curled.z * cos(hinge)  // 翻到对面
        return SIMD3(Float(hingedX), Float(curled.y), Float(max(hingedZ, 0)))  // z 不穿到纸下
    }

    /// 页角卷曲。
    private static func cornerCurl(
        curlAmount: CGFloat,
        direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        height: CGFloat,
        pageOriginX: CGFloat,
        restX: CGFloat,
        restY: CGFloat
    ) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        guard curlAmount > 0.002 else { return (restX, restY, 0) }  // 几乎没卷就平铺

        let beta: CGFloat = 0.36  // 卷轴和底边的夹角
        let radius = max(pageWidth * 0.22, 24)  // 卷筒半径，太小会折
        let travel = hypot(pageWidth, height * 0.18) * curlAmount * 1.05  // 卷轴走过的弧长

        let fromFreeX: CGFloat  // 离自由边的距离
        switch direction {  // 向前铰链在左，向后在右
        case .forward:  // 下一摊，页从右往左合
            fromFreeX = (pageOriginX + pageWidth) - restX  // 向前：右沿是自由边
        case .backward:  // 上一摊，页从左往右合
            fromFreeX = restX - pageOriginX  // 向后：左沿是自由边
        }

        let xR = max(fromFreeX * cos(beta) + restY * sin(beta), 0)  // 转到卷轴坐标
        let yR = -fromFreeX * sin(beta) + restY * cos(beta)  // 沿卷轴方向

        if xR >= travel {  // 还没被卷到
            return (restX, restY, 0)  // 保持平
        }

        let arc = travel - xR  // 已经卷进去的长度
        let phi = min(arc / radius, 0.82 * .pi)  // 卷角封顶，避免卷穿

        let curledXR = travel - radius * sin(phi)  // 卷后在卷轴系的 x
        let curledZ = radius * (1 - cos(phi))  // 抬起来的高度

        let fromFreeX2 = curledXR * cos(beta) - yR * sin(beta)  // 转回页坐标
        let fromBottom2 = curledXR * sin(beta) + yR * cos(beta)  // y 也跟着转

        let x: CGFloat  // 页坐标 x
        switch direction {  // 向前铰链在左，向后在右
        case .forward:  // 下一摊，页从右往左合
            x = (pageOriginX + pageWidth) - fromFreeX2  // 向前：从右沿量
        case .backward:  // 上一摊，页从左往右合
            x = pageOriginX + fromFreeX2  // 向后：从左沿量
        }
        return (x, fromBottom2, curledZ)  // 给铰链再用
    }
}

/// 翻页前后两页的位图。渲染失败则不做 3D 翻页。
struct BookPageTurnSnapshot {
    let front: CGImage  // 翻页正面（当前页）
    let back: CGImage  // 背面（下一页或纸色）
    let pixelScale: CGFloat  // 打图时的 scale，对网格 UV
}

/// 把 SwiftUI 页打成位图给 SceneKit。
enum BookPageTurnSnapshotRenderer {
    @MainActor
    /// 正反页打成 CGImage。
    static func render<Front: View, Back: View>(
        front: Front,
        back: Back,
        size: CGSize
    ) -> BookPageTurnSnapshot? {
        guard size.width > 1, size.height > 1 else { return nil }  // 还没布局好不打

        let scale = NSScreen.main?.backingScaleFactor ?? 2  // 视网膜
        let frontRenderer = ImageRenderer(content: front.frame(width: size.width, height: size.height))  // 正面钉死尺寸
        frontRenderer.scale = scale  // 和屏幕一致
        let backRenderer = ImageRenderer(content: back.frame(width: size.width, height: size.height))  // 背面同样尺寸
        backRenderer.scale = scale  // 同样 scale

        guard let frontImage = frontRenderer.cgImage,  // 渲染失败就不做 3D
              let backImage = backRenderer.cgImage else {  // 缺一面也不做
            return nil  // 调用方走无动画翻页
        }
        return BookPageTurnSnapshot(front: frontImage, back: backImage, pixelScale: scale)  // 给 SceneKit 贴图
    }
}

/// 背面没有正文时垫一层纸色，避免翻过去漏空。
struct BookPageBackSurface: View {
    let direction: BookPageTurnDirection  // 渐变朝书脊
    let width: CGFloat  // 和页同宽
    let height: CGFloat  // 和页同高

    /// 翻页过程中这一层的画面。
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BookTheme.pageRight.opacity(0.96),  // 靠外沿稍亮
                    BookTheme.pageLeft.opacity(0.90),  // 中间
                    BookTheme.pageEdge.opacity(0.76),  // 靠脊暗一点
                ],
                startPoint: direction == .forward ? .leading : .trailing,  // 向前脊在左
                endPoint: direction == .forward ? .trailing : .leading  // 渐变指向自由边
            )
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),  // 对角阴影
                    Color.clear,  // 中间透
                    Color.white.opacity(0.06),  // 对角色纸
                ],
                startPoint: .topLeading,  // 左上暗
                endPoint: .bottomTrailing  // 右下亮
            )
            BookInterface.HeaderOrnament()  // 和正页同一纹样
                .opacity(0.26)  // 背面淡
                .padding(.top, 8)  // 别贴顶
        }
        .bookPaperTexture()  // 纸纹
        .frame(width: width, height: height)  // 钉死
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))  // 和正页圆角一致
    }
}

/// 盖在书页上的翻页层，动画完就卸。
struct BookPageTurnSheet: View {
    let progress: CGFloat  // 和上层同一进度
    let direction: BookPageTurnDirection  // 渐变朝书脊
    let pageWidth: CGFloat  // 单页宽
    let height: CGFloat  // 和页同高
    let canvasWidth: CGFloat  // 整摊宽，含书脊
    let pageOriginX: CGFloat  // 这一页左缘
    let spineOriginX: CGFloat  // 书脊起点，Sheet 目前没用
    let spineWidth: CGFloat  // 书脊宽，Sheet 目前没用
    let snapshot: BookPageTurnSnapshot?  // nil 则空层

    /// 翻页过程中这一层的画面。
    var body: some View {
        BookPageTurnSceneView(  // AppKit 承载
            progress: progress,
            direction: direction,
            pageWidth: pageWidth,
            height: height,
            canvasWidth: canvasWidth,
            pageOriginX: pageOriginX,
            snapshot: snapshot
        )
        .frame(width: canvasWidth, height: height)  // 盖住整摊
        .allowsHitTesting(false)  // 手势还给下面的页
    }
}

/// SceneKit 网格翻页。AppKit 承载，SwiftUI 只传进度。
private struct BookPageTurnSceneView: NSViewRepresentable {
    let progress: CGFloat  // 和上层同一进度
    let direction: BookPageTurnDirection  // 渐变朝书脊
    let pageWidth: CGFloat  // 单页宽
    let height: CGFloat  // 和页同高
    let canvasWidth: CGFloat  // 整摊宽，含书脊
    let pageOriginX: CGFloat  // 这一页左缘
    let snapshot: BookPageTurnSnapshot?  // nil 则空层

    /// 持有 Scene 和相机，update 里改网格。
    func makeCoordinator() -> Coordinator {
        Coordinator()  // 场景活在 coordinator 里
    }

    /// 透明 SCNView，关默认灯和相机控制。
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()  // 每次 make 一个
        view.scene = context.coordinator.scene  // 防 SwiftUI 换掉
        view.backgroundColor = .clear  // 透出下面已翻开的摊
        view.wantsLayer = true  // 才能透明
        view.layer?.isOpaque = false  // 别涂黑
        view.antialiasingMode = .multisampling4X  // 卷边锯齿
        view.autoenablesDefaultLighting = false  // 自己两盏灯
        view.allowsCameraControl = false  // 不能拖场景
        view.rendersContinuously = false  // 进度变了再画
        view.pointOfView = context.coordinator.cameraNode  // 再绑一次
        return view  // representable 持有
    }

    /// 进度变了重算网格，不重建 scene。
    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.update(  // 只改网格
            progress: progress,
            direction: direction,
            pageWidth: pageWidth,
            height: height,
            canvasWidth: canvasWidth,
            pageOriginX: pageOriginX,
            snapshot: snapshot
        )
        view.scene = context.coordinator.scene  // 防 SwiftUI 换掉
        view.pointOfView = context.coordinator.cameraNode  // 再绑一次
        view.play(nil)  // 踢一帧
    }

    /// 持有 SCNView，避免 representable 重建丢动画。
    final class Coordinator {
        let scene = SCNScene()  // 透明底
        let cameraNode = SCNNode()  // 透视，对准摊中心
        private let root = SCNNode()  // 页网格的父
        private let frontNode = SCNNode()  // 正面
        private let backNode = SCNNode()  // 背面，沿法线偏一点
        private var lastSignature: String = ""  // 参数没变不重算

        /// 建透明场景、透视相机和两盏灯。
        init() {
            scene.background.contents = NSColor.clear  // 透
            scene.rootNode.addChildNode(root)  // 页挂这
            root.addChildNode(frontNode)  // 正面
            root.addChildNode(backNode)  // 背面

            let camera = SCNCamera()  // 透视，让卷边有近大远小
            camera.usesOrthographicProjection = false  // 正交会看起来像纸片
            camera.fieldOfView = 30  // 窄一点，畸变小
            camera.zNear = 2  // 别裁到页
            camera.zFar = 8000  // 相机按页高推远
            cameraNode.camera = camera  // 挂上
            scene.rootNode.addChildNode(cameraNode)  // 和页同一空间

            let ambient = SCNNode()  // 补底
            let ambientLight = SCNLight()  // 环境
            ambientLight.type = .ambient  // 无方向
            ambientLight.intensity = 780  // 纸不要太阴
            ambientLight.color = NSColor(white: 1, alpha: 1)  // 白
            ambient.light = ambientLight  // 挂
            scene.rootNode.addChildNode(ambient)  // 全局

            let sun = SCNNode()  // 方向光打出卷边阴影
            let sunLight = SCNLight()  // 平行光
            sunLight.type = .directional  // 像窗光
            sunLight.intensity = 560  // 别过曝字
            sunLight.color = NSColor(white: 1, alpha: 1)  // 白
            sun.light = sunLight  // 挂
            sun.eulerAngles = SCNVector3(-0.55, 0.35, 0.12)  // 左上前方打
            scene.rootNode.addChildNode(sun)  // 全局
        }

        /// 签名没变就跳过；变了重算相机和网格。
        func update(
            progress: CGFloat,
            direction: BookPageTurnDirection,
            pageWidth: CGFloat,
            height: CGFloat,
            canvasWidth: CGFloat,
            pageOriginX: CGFloat,
            snapshot: BookPageTurnSnapshot?
        ) {
            let signature = "\(progress)|\(String(describing: direction))|\(pageWidth)|\(height)|\(canvasWidth)|\(pageOriginX)|\(snapshot == nil)"  // 这些变了才重算
            guard signature != lastSignature else { return }  // 动画帧也只在进度变时算
            lastSignature = signature  // 记下

            let fov = cameraNode.camera?.fieldOfView ?? 30  // 和 init 一致
            let dist = (height / 2) / tan((fov * .pi / 180) / 2)  // 让页高刚好装满视野
            cameraNode.position = SCNVector3(canvasWidth / 2, height / 2, dist)  // 对准摊中心
            cameraNode.look(at: SCNVector3(canvasWidth / 2, height / 2, 0))  // 看向纸面

            guard let snapshot else {  // 没位图就卸网格
                frontNode.geometry = nil  // 正面空
                backNode.geometry = nil  // 背面空
                return  // 等下次有图
            }

            let mesh = BookPageTurnMesh.make(  // 按进度变形
                progress: progress,
                direction: direction,
                pageWidth: pageWidth,
                height: height,
                pageOriginX: pageOriginX
            )

            frontNode.geometry = mesh.front  // 正面
            backNode.geometry = mesh.back  // 背面（指数相反，沿法线偏）
            frontNode.geometry?.firstMaterial = Self.material(image: snapshot.front)  // 贴正面
            backNode.geometry?.firstMaterial = Self.material(image: snapshot.back)  // 贴背面
        }

        /// 双面贴图，避免翻过去漏空。
        private static func material(image: CGImage) -> SCNMaterial {
            let material = SCNMaterial()  // 每面一份
            material.diffuse.contents = image  // 位图
            material.lightingModel = .lambert  // 卷边能见明暗
            material.isDoubleSided = false  // 靠背面那张网格补
            material.cullMode = .back  // 背面剔除，避免 z-fight
            material.writesToDepthBuffer = true  // 两面要互挡
            material.readsFromDepthBuffer = true  // 读深度
            material.diffuse.magnificationFilter = .linear  // 放大不锯齿
            material.diffuse.minificationFilter = .linear  // 缩小不闪
            return material  // 给节点
        }
    }
}

/// 翻页网格顶点。改尺寸要重算。
private enum BookPageTurnMesh {
    static let columns = 52  // 横向分段，卷边要够密
    static let rows = 28  // 纵向少一点省顶点

    /// 建翻页网格节点。
    static func make(
        progress: CGFloat,
        direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        height: CGFloat,
        pageOriginX: CGFloat
    ) -> (front: SCNGeometry, back: SCNGeometry) {
        let cols = columns  // 局部名短
        let rows = rows  // 同上
        var positions: [SCNVector3] = []  // 正面顶点
        var normals: [SCNVector3] = []  // 正面法线
        var uvs: [CGPoint] = []  // 正反共用 UV
        positions.reserveCapacity(cols * rows)  // 避免反复扩

        var raw: [SIMD3<Float>] = []  // 先 SIMD 方便叉积
        raw.reserveCapacity(cols * rows)  // 预分配

        for row in 0..<rows {  // 第二遍算法线
            let v = CGFloat(row) / CGFloat(rows - 1)  // 0...1
            for col in 0..<cols {  // 邻点差分
                let u = CGFloat(col) / CGFloat(cols - 1)  // 0...1
                raw.append(  // 变形后的点
                    BookPageMeshDeformer.pose(  // 卷角+铰链
                        u: u,
                        v: v,
                        progress: progress,
                        direction: direction,
                        pageWidth: pageWidth,
                        height: height,
                        pageOriginX: pageOriginX
                    )
                )
                let texU: CGFloat = direction == .forward ? u : (1 - u)  // 向后翻 UV 要镜像，字才不反
                uvs.append(CGPoint(x: texU, y: 1 - v))  // SceneKit v 向上，图是向下
            }
        }

        for row in 0..<rows {  // 第二遍算法线
            for col in 0..<cols {  // 邻点差分
                let i = row * cols + col  // 线性下标
                let p = raw[i]  // 当前点
                positions.append(SCNVector3(p.x, p.y, p.z))  // 转 SceneKit

                let du: SIMD3<Float>  // 横向切
                if col < cols - 1 {  // 有右邻用右
                    du = raw[i + 1] - p  // 向前差
                } else {  // 正常
                    du = p - raw[i - 1]  // 避免越界
                }
                let dv: SIMD3<Float>  // 纵向切
                if row < rows - 1 {  // 有上邻
                    dv = raw[i + cols] - p  // 向前差
                } else {  // 正常
                    dv = p - raw[i - cols]  // 向后差
                }
                let crossed = simd_cross(du, dv)  // 法线
                let n: SIMD3<Float>  // 单位法线
                if simd_length(crossed) < 1e-5 {  // 退化三角形
                    n = SIMD3(0, 0, 1)  // 朝外
                } else {  // 正常
                    n = simd_normalize(crossed)  // 单位化
                }
                normals.append(SCNVector3(n.x, n.y, n.z))  // 正面法线
            }
        }

        var frontIndices: [UInt32] = []  // 正面绕序
        var backIndices: [UInt32] = []  // 背面绕序相反
        frontIndices.reserveCapacity((cols - 1) * (rows - 1) * 6)  // 每格两个三角
        for row in 0..<(rows - 1) {  // 格子
            for col in 0..<(cols - 1) {  // 格子
                let a = UInt32(row * cols + col)  // 左下
                let b = a + 1  // 右下
                let c = a + UInt32(cols)  // 左上
                let d = c + 1  // 右上
                frontIndices.append(contentsOf: [a, c, b, b, c, d])  // 正面 CCW
                backIndices.append(contentsOf: [a, b, c, b, d, c])  // 背面绕反，法线才朝外
            }
        }

        let offset: Float = 0.35  // 背面沿 -n 挪，防 z-fight
        var backPositions: [SCNVector3] = []  // 偏后的点
        var backNormals: [SCNVector3] = []  // 反向法线
        backPositions.reserveCapacity(positions.count)  // 预分配
        for i in 0..<positions.count {  // 逐点偏
            let n = normals[i]  // 正面法线
            let nx = CGFloat(n.x)  // 分量
            let ny = CGFloat(n.y)  // 分量
            let nz = CGFloat(n.z)  // 分量
            let off = CGFloat(offset)  // 偏量
            backPositions.append(  // 沿 -n
                SCNVector3(  // x/y/z 都减
                    positions[i].x - nx * off,  // x
                    positions[i].y - ny * off,  // y
                    positions[i].z - nz * off  // z
                )
            )
            backNormals.append(SCNVector3(-n.x, -n.y, -n.z))  // 翻法线
        }

        return (  // 正反两套几何
            geometry(positions: positions, normals: normals, uvs: uvs, indices: frontIndices),  // 正面
            geometry(positions: backPositions, normals: backNormals, uvs: uvs, indices: backIndices)  // 背面，UV 同一份
        )
    }

    /// 顶点缓冲。
    private static func geometry(
        positions: [SCNVector3],
        normals: [SCNVector3],
        uvs: [CGPoint],
        indices: [UInt32]
    ) -> SCNGeometry {
        let vertexSource = SCNGeometrySource(vertices: positions)  // 位置
        let normalSource = SCNGeometrySource(normals: normals)  // 法线
        let uvSource = SCNGeometrySource(textureCoordinates: uvs)  // 贴图
        let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }  // UInt32 索引
        let element = SCNGeometryElement(  // 三角
            data: data,  // 缓冲
            primitiveType: .triangles,  // 每三个一三角
            primitiveCount: indices.count / 3,  // 个数
            bytesPerIndex: MemoryLayout<UInt32>.size  // 4 字节
        )
        return SCNGeometry(sources: [vertexSource, normalSource, uvSource], elements: [element])  // 一份几何
    }
}

/// 上层卷走时露出来的下一摊，透明度跟进度走。
struct BookSpreadRevealLayer<Spread: View>: View {
    let progress: CGFloat  // 和上层同一进度
    @ViewBuilder var spread: () -> Spread  // 下一摊内容

    /// 进度先过 mesh easing，再拿去改透明和形变。
    private var eased: CGFloat { BookPageTurnEasing.transform(min(max(progress, 0), 1)) }

    /// 翻页过程中这一层的画面。
    var body: some View {
        spread()  // 下一摊
            .opacity(min(1, 0.28 + eased * 0.72))  // 一开始就能隐约看见，翻完全显
    }
}

/// 阅读摊翻页用的 timing curve，和 mesh easing 接近。
extension Animation {
    /// 翻页 timing curve，起得慢落得稳，和 mesh easing 接近。
    static var bookPageTurn: Animation {
        .timingCurve(0.2, 0.16, 0.28, 1.0, duration: 0.86)  // 起得慢、落得稳，和 mesh easing 接近
    }
}
