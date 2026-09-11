import AppKit
import SceneKit
import SwiftUI

enum BookPageTurnDirection {
    case forward
    case backward
}

enum BookPageTurnEasing {
    static func transform(_ progress: CGFloat) -> CGFloat {
        let t = min(max(progress, 0), 1)
        return t * t * (3 - 2 * t)
    }

    static func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// Corner-led paper curl. The sheet stays a single developable surface:
/// wrap never goes over the cylinder top (that used to rip the mesh),
/// and landing is a hinge around the spine instead of a linear collapse.
enum BookPageMeshDeformer {
    static func pose(
        u: CGFloat,
        v: CGFloat,
        progress: CGFloat,
        direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        height: CGFloat,
        pageOriginX: CGFloat
    ) -> SIMD3<Float> {
        let t = BookPageTurnEasing.transform(progress)
        let uu = min(max(u, 0), 1)
        let vv = min(max(v, 0), 1)
        let restX: CGFloat
        let spineX: CGFloat
        switch direction {
        case .forward:
            spineX = pageOriginX
            restX = pageOriginX + uu * pageWidth
        case .backward:
            spineX = pageOriginX + pageWidth
            restX = pageOriginX + pageWidth - uu * pageWidth
        }
        let restY = vv * height

        let flatten = BookPageTurnEasing.smoothstep(0.64, 1, t)
        let curlAmount = t * (1 - flatten)

        let curled = cornerCurl(
            curlAmount: curlAmount,
            direction: direction,
            pageWidth: pageWidth,
            height: height,
            pageOriginX: pageOriginX,
            restX: restX,
            restY: restY
        )

        let hinge = CGFloat.pi * flatten
        let relX = curled.x - spineX
        let hingedX = spineX + relX * cos(hinge) - curled.z * sin(hinge)
        let hingedZ = relX * sin(hinge) + curled.z * cos(hinge)
        return SIMD3(Float(hingedX), Float(curled.y), Float(max(hingedZ, 0)))
    }

    private static func cornerCurl(
        curlAmount: CGFloat,
        direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        height: CGFloat,
        pageOriginX: CGFloat,
        restX: CGFloat,
        restY: CGFloat
    ) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        guard curlAmount > 0.002 else { return (restX, restY, 0) }

        let beta: CGFloat = 0.36
        let radius = max(pageWidth * 0.22, 24)
        let travel = hypot(pageWidth, height * 0.18) * curlAmount * 1.05

        let fromFreeX: CGFloat
        switch direction {
        case .forward:
            fromFreeX = (pageOriginX + pageWidth) - restX
        case .backward:
            fromFreeX = restX - pageOriginX
        }

        let xR = max(fromFreeX * cos(beta) + restY * sin(beta), 0)
        let yR = -fromFreeX * sin(beta) + restY * cos(beta)

        if xR >= travel {
            return (restX, restY, 0)
        }

        let arc = travel - xR
        let phi = min(arc / radius, 0.82 * .pi)

        let curledXR = travel - radius * sin(phi)
        let curledZ = radius * (1 - cos(phi))

        let fromFreeX2 = curledXR * cos(beta) - yR * sin(beta)
        let fromBottom2 = curledXR * sin(beta) + yR * cos(beta)

        let x: CGFloat
        switch direction {
        case .forward:
            x = (pageOriginX + pageWidth) - fromFreeX2
        case .backward:
            x = pageOriginX + fromFreeX2
        }
        return (x, fromBottom2, curledZ)
    }
}

struct BookPageTurnSnapshot {
    let front: CGImage
    let back: CGImage
    let pixelScale: CGFloat
}

enum BookPageTurnSnapshotRenderer {
    @MainActor
    static func render<Front: View, Back: View>(
        front: Front,
        back: Back,
        size: CGSize
    ) -> BookPageTurnSnapshot? {
        guard size.width > 1, size.height > 1 else { return nil }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let frontRenderer = ImageRenderer(content: front.frame(width: size.width, height: size.height))
        frontRenderer.scale = scale
        let backRenderer = ImageRenderer(content: back.frame(width: size.width, height: size.height))
        backRenderer.scale = scale

        guard let frontImage = frontRenderer.cgImage,
              let backImage = backRenderer.cgImage else {
            return nil
        }
        return BookPageTurnSnapshot(front: frontImage, back: backImage, pixelScale: scale)
    }
}

/// Paper back shown when the reverse of the leaf has no page content.
struct BookPageBackSurface: View {
    let direction: BookPageTurnDirection
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BookTheme.pageRight.opacity(0.96),
                    BookTheme.pageLeft.opacity(0.90),
                    BookTheme.pageEdge.opacity(0.76),
                ],
                startPoint: direction == .forward ? .leading : .trailing,
                endPoint: direction == .forward ? .trailing : .leading
            )
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.clear,
                    Color.white.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            BookInterface.HeaderOrnament()
                .opacity(0.26)
                .padding(.top, 8)
        }
        .bookPaperTexture()
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct BookPageTurnSheet: View {
    let progress: CGFloat
    let direction: BookPageTurnDirection
    let pageWidth: CGFloat
    let height: CGFloat
    let canvasWidth: CGFloat
    let pageOriginX: CGFloat
    let spineOriginX: CGFloat
    let spineWidth: CGFloat
    let snapshot: BookPageTurnSnapshot?

    var body: some View {
        BookPageTurnSceneView(
            progress: progress,
            direction: direction,
            pageWidth: pageWidth,
            height: height,
            canvasWidth: canvasWidth,
            pageOriginX: pageOriginX,
            snapshot: snapshot
        )
        .frame(width: canvasWidth, height: height)
        .allowsHitTesting(false)
    }
}

private struct BookPageTurnSceneView: NSViewRepresentable {
    let progress: CGFloat
    let direction: BookPageTurnDirection
    let pageWidth: CGFloat
    let height: CGFloat
    let canvasWidth: CGFloat
    let pageOriginX: CGFloat
    let snapshot: BookPageTurnSnapshot?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.backgroundColor = .clear
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.rendersContinuously = false
        view.pointOfView = context.coordinator.cameraNode
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.update(
            progress: progress,
            direction: direction,
            pageWidth: pageWidth,
            height: height,
            canvasWidth: canvasWidth,
            pageOriginX: pageOriginX,
            snapshot: snapshot
        )
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.cameraNode
        view.play(nil)
    }

    final class Coordinator {
        let scene = SCNScene()
        let cameraNode = SCNNode()
        private let root = SCNNode()
        private let frontNode = SCNNode()
        private let backNode = SCNNode()
        private var lastSignature: String = ""

        init() {
            scene.background.contents = NSColor.clear
            scene.rootNode.addChildNode(root)
            root.addChildNode(frontNode)
            root.addChildNode(backNode)

            let camera = SCNCamera()
            camera.usesOrthographicProjection = false
            camera.fieldOfView = 30
            camera.zNear = 2
            camera.zFar = 8000
            cameraNode.camera = camera
            scene.rootNode.addChildNode(cameraNode)

            let ambient = SCNNode()
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.intensity = 780
            ambientLight.color = NSColor(white: 1, alpha: 1)
            ambient.light = ambientLight
            scene.rootNode.addChildNode(ambient)

            let sun = SCNNode()
            let sunLight = SCNLight()
            sunLight.type = .directional
            sunLight.intensity = 560
            sunLight.color = NSColor(white: 1, alpha: 1)
            sun.light = sunLight
            sun.eulerAngles = SCNVector3(-0.55, 0.35, 0.12)
            scene.rootNode.addChildNode(sun)
        }

        func update(
            progress: CGFloat,
            direction: BookPageTurnDirection,
            pageWidth: CGFloat,
            height: CGFloat,
            canvasWidth: CGFloat,
            pageOriginX: CGFloat,
            snapshot: BookPageTurnSnapshot?
        ) {
            let signature = "\(progress)|\(String(describing: direction))|\(pageWidth)|\(height)|\(canvasWidth)|\(pageOriginX)|\(snapshot == nil)"
            guard signature != lastSignature else { return }
            lastSignature = signature

            let fov = cameraNode.camera?.fieldOfView ?? 30
            let dist = (height / 2) / tan((fov * .pi / 180) / 2)
            cameraNode.position = SCNVector3(canvasWidth / 2, height / 2, dist)
            cameraNode.look(at: SCNVector3(canvasWidth / 2, height / 2, 0))

            guard let snapshot else {
                frontNode.geometry = nil
                backNode.geometry = nil
                return
            }

            let mesh = BookPageTurnMesh.make(
                progress: progress,
                direction: direction,
                pageWidth: pageWidth,
                height: height,
                pageOriginX: pageOriginX
            )

            frontNode.geometry = mesh.front
            backNode.geometry = mesh.back
            frontNode.geometry?.firstMaterial = Self.material(image: snapshot.front)
            backNode.geometry?.firstMaterial = Self.material(image: snapshot.back)
        }

        private static func material(image: CGImage) -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = image
            material.lightingModel = .lambert
            material.isDoubleSided = false
            material.cullMode = .back
            material.writesToDepthBuffer = true
            material.readsFromDepthBuffer = true
            material.diffuse.magnificationFilter = .linear
            material.diffuse.minificationFilter = .linear
            return material
        }
    }
}

private enum BookPageTurnMesh {
    static let columns = 52
    static let rows = 28

    static func make(
        progress: CGFloat,
        direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        height: CGFloat,
        pageOriginX: CGFloat
    ) -> (front: SCNGeometry, back: SCNGeometry) {
        let cols = columns
        let rows = rows
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        positions.reserveCapacity(cols * rows)

        var raw: [SIMD3<Float>] = []
        raw.reserveCapacity(cols * rows)

        for row in 0..<rows {
            let v = CGFloat(row) / CGFloat(rows - 1)
            for col in 0..<cols {
                let u = CGFloat(col) / CGFloat(cols - 1)
                raw.append(
                    BookPageMeshDeformer.pose(
                        u: u,
                        v: v,
                        progress: progress,
                        direction: direction,
                        pageWidth: pageWidth,
                        height: height,
                        pageOriginX: pageOriginX
                    )
                )
                let texU: CGFloat = direction == .forward ? u : (1 - u)
                uvs.append(CGPoint(x: texU, y: 1 - v))
            }
        }

        for row in 0..<rows {
            for col in 0..<cols {
                let i = row * cols + col
                let p = raw[i]
                positions.append(SCNVector3(p.x, p.y, p.z))

                let du: SIMD3<Float>
                if col < cols - 1 {
                    du = raw[i + 1] - p
                } else {
                    du = p - raw[i - 1]
                }
                let dv: SIMD3<Float>
                if row < rows - 1 {
                    dv = raw[i + cols] - p
                } else {
                    dv = p - raw[i - cols]
                }
                let crossed = simd_cross(du, dv)
                let n: SIMD3<Float>
                if simd_length(crossed) < 1e-5 {
                    n = SIMD3(0, 0, 1)
                } else {
                    n = simd_normalize(crossed)
                }
                normals.append(SCNVector3(n.x, n.y, n.z))
            }
        }

        var frontIndices: [UInt32] = []
        var backIndices: [UInt32] = []
        frontIndices.reserveCapacity((cols - 1) * (rows - 1) * 6)
        for row in 0..<(rows - 1) {
            for col in 0..<(cols - 1) {
                let a = UInt32(row * cols + col)
                let b = a + 1
                let c = a + UInt32(cols)
                let d = c + 1
                frontIndices.append(contentsOf: [a, c, b, b, c, d])
                backIndices.append(contentsOf: [a, b, c, b, d, c])
            }
        }

        let offset: Float = 0.35
        var backPositions: [SCNVector3] = []
        var backNormals: [SCNVector3] = []
        backPositions.reserveCapacity(positions.count)
        for i in 0..<positions.count {
            let n = normals[i]
            let nx = CGFloat(n.x)
            let ny = CGFloat(n.y)
            let nz = CGFloat(n.z)
            let off = CGFloat(offset)
            backPositions.append(
                SCNVector3(
                    positions[i].x - nx * off,
                    positions[i].y - ny * off,
                    positions[i].z - nz * off
                )
            )
            backNormals.append(SCNVector3(-n.x, -n.y, -n.z))
        }

        return (
            geometry(positions: positions, normals: normals, uvs: uvs, indices: frontIndices),
            geometry(positions: backPositions, normals: backNormals, uvs: uvs, indices: backIndices)
        )
    }

    private static func geometry(
        positions: [SCNVector3],
        normals: [SCNVector3],
        uvs: [CGPoint],
        indices: [UInt32]
    ) -> SCNGeometry {
        let vertexSource = SCNGeometrySource(vertices: positions)
        let normalSource = SCNGeometrySource(normals: normals)
        let uvSource = SCNGeometrySource(textureCoordinates: uvs)
        let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(
            data: data,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        return SCNGeometry(sources: [vertexSource, normalSource, uvSource], elements: [element])
    }
}

/// Underneath spread revealed while the top sheet curls away.
struct BookSpreadRevealLayer<Spread: View>: View {
    let progress: CGFloat
    @ViewBuilder var spread: () -> Spread

    private var eased: CGFloat { BookPageTurnEasing.transform(min(max(progress, 0), 1)) }

    var body: some View {
        spread()
            .opacity(min(1, 0.28 + eased * 0.72))
    }
}

extension Animation {
    static var bookPageTurn: Animation {
        .timingCurve(0.2, 0.16, 0.28, 1.0, duration: 0.86)
    }
}
