require daslib/media
require math

options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code


struct Base
    hasStarted: bool
    hasFinished: bool
    button: float
    zeroPos: float2
    pos: float2
    score: float
    reqNps: int
    hardLvl: int


struct Rocket
    pos: float2
    speed: float2
    rad: float
    baseFuel: float
    maxBaseFuel: float
    extraFuel: float
    speedup: float
    addGravity: float


struct Particle
    pos: float2
    dis: float
    ang: float
    rad: float
    spd: float
    life: int
    moveX: float
    color: uint


struct Nps
    pos: float2
    realPos: float2
    imgYpos: float
    id: string
    rad: float
    moveY: float
    ang: float


struct NpsCfg
    color: uint
    size: float2
    imgSize: int


var
    base: Base
    rocket: Rocket
    particles: array<Particle>
    explosions: array<Particle>
    npses: array<Nps>
    back_music: PcmSound <- create_sound("back.mp3")


var weight_png: Image
var bonus_png: Image
var thorn_png: Image
var cloud_png: Image
var gas_png: Image


let
    npsIds <- [{ auto[]
      "GAS"; "CLOUD"; "THORN"; "BONUS"
    }]
    volume = 0.2


var
    npsCfgs <- {{
        "GAS" => [[ NpsCfg color = 0x336699, size = float2(25.0, 20.0), imgSize = 25 ]];
        "CLOUD" => [[ NpsCfg color = 0x666666, size = float2(60.0, 30.0), imgSize = 40 ]];
        "THORN" => [[ NpsCfg color = 0x996633, size = float2(35.0, 30.0), imgSize = 25 ]];
        "BONUS" => [[ NpsCfg color = 0x51ae5c, size = float2(25.0, 20.0), imgSize = 20 ]]
    }}

let
    BALL = 0xb564b6
    WHITE = 0xCCCCCC
    GREY = 0x999999
    BLUE = 0x336699
    GARKGREY = 0x333333
    GRAVITY = 100.0
    MAX_SPEED = 5.0
    MIN_SPEED = -3.0
    MAX_SPEEDUP = 0.3
    sw = float(get_screen_width())
    sh = float(get_screen_height())


/* ------------------------------------------------------ */


def calcPoint(p: float2; angle, radius: float) : float2
    var res: float2
    res.x = p.x + sin(angle) * radius
    res.y = p.y + cos(angle) * radius
    return res


/* ------------------------------------------------------ */


def landReset(var b: Base)
    weight_png <- create_image("weight.png")
    bonus_png <- create_image("bonus.png")
    thorn_png <- create_image("thorn.png")
    cloud_png <- create_image("cloud.png")
    gas_png <- create_image("gas.png")

    b.hasStarted = false
    b.hasFinished = false
    b.button = 0.0
    b.zeroPos.x = sw / 5.0
    b.zeroPos.y = sh - 100.0
    b.pos.x = 0.0
    b.pos.y = 0.0
    b.score = 0.0
    b.reqNps = 7
    b.hardLvl = 0


def rocketReset(var r: Rocket)
    r.rad = 25.0
    r.pos.x = 0.0
    r.pos.y = 0.0
    r.baseFuel = 20.0
    r.maxBaseFuel = 20.0
    r.extraFuel = 10.0
    r.speedup = 0.0
    r.speed.x = 0.0
    r.speed.y = 0.0
    r.addGravity = 0.0


/* ---------------- RENDER ---------------- */


def landRender(b: Base; r: Rocket)
    let bottomLine = int(b.zeroPos.y + r.rad + 2.0)
    line(0, 50, int(sw), 50, GREY)
    line(0, bottomLine, int(sw), bottomLine, GREY)

    let dist = int(b.pos.x)
    let xPos = dist % int(sw)
    for i in range(0, int(sw * 2.0 / 50.0))
        let h = i % 2 == 0 ? 10 : 5
        let x = i * 50 - xPos
        line(x, bottomLine, x, bottomLine - h, GREY)

    let distView = dist / 100
    let scoreView = distView + int(b.score)
    set_font_size(16)
    text_out(400,  5, "SCORE: {scoreView}", WHITE)
    text_out(400, 25, "Difficulty: {b.hardLvl}", WHITE)


def particlesRender(pList: array<Particle>)
    for p in pList
        let pos = calcPoint(p.pos, p.ang, p.dis)
        circle(int(pos.x), int(pos.y), int(p.rad), p.color)


def npsRender(var npsList: array<Nps>; b: Base)
    for nps in npsList
        let xPos = int(nps.realPos.x - b.pos.x)
        let yPos = int(b.zeroPos.y + nps.imgYpos)
        let cfg = npsCfgs[nps.id]
        let img: Image := (nps.id == "CLOUD" ? cloud_png
          : nps.id == "THORN" ? thorn_png
          : nps.id == "GAS" ? gas_png
          : bonus_png)
        draw_image(img, xPos - cfg.imgSize, yPos - cfg.imgSize)

    for nps in npsList
        let cfg = npsCfgs[nps.id]
        let xPos = int(nps.realPos.x - b.pos.x)
        let yPos = int(b.zeroPos.y + nps.realPos.y)
        circle(xPos, yPos, int(nps.rad), cfg.color)


def breafingRender(b: Base)
    let w: int = int(sw / 2.0)
    let h: int = 450
    let xPos: int = (int(sw) - w) / 2
    let yPos: int = (int(sh) - h) / 2
    fill_rect(xPos, yPos, w, h, GARKGREY)
    fill_rect(xPos + 2, yPos + 2, w - 4, h - 4, 0x000000)

    let padding: int = int(w / 16)
    set_font_size(18)
    text_out(xPos + padding, yPos + padding, "Use the LMB to fly the ball.The amount of helium \nin the balloon is spent on the flight.", WHITE)
    set_font_size(16)
    text_out(xPos + padding + 100, yPos + padding +  70, "Additional helium reserves will allow you \nto fly further", GREY)
    text_out(xPos + padding + 100, yPos + padding + 130, "The bonus box will add you extra points \nto score", GREY)
    text_out(xPos + padding + 100, yPos + padding + 190, "A rainy cloud will wet your balloon and make \nit heavier. We'll have to spend more helium \nfor the flight", GREY)
    text_out(xPos + padding + 100, yPos + padding + 280, "Office button will destroy your ball and the \ngame will over", GREY)
    text_out(xPos + padding + 100, yPos + padding + 350, "Press LMB to start...", WHITE)
    draw_image(gas_png,   xPos + padding + 15, yPos + padding + 70)
    draw_image(bonus_png, xPos + padding + 20, yPos + padding + 130)
    draw_image(cloud_png, xPos + padding, yPos + padding + 190)
    draw_image(thorn_png, xPos + padding + 15, yPos + padding + 280)


def gameOverRender(b: Base)
    let w: int = int(sw / 3.0)
    let h: int = int(sh / 3.0)
    let xPos: int = (int(sw) - w) / 2
    let yPos: int = (int(sh) - h) / 2
    fill_rect(xPos, yPos, w, h, GARKGREY)
    fill_rect(xPos + 2, yPos + 2, w - 4, h - 4, 0x000000)

    let scoreView = int(b.pos.x) / 100 + int(b.score)
    set_font_size(24)
    text_out(xPos + int(w / 5),  yPos + int(h / 4), "GAME OVER!", WHITE)
    text_out(xPos + int(w / 5),  yPos + int(h / 2) - int(h / 10), "You score: {scoreView}", WHITE)
    set_font_size(16)
    text_out(xPos + int(w / 5),  yPos + int(h / 2) + int(h / 8), "Press SPACE to start again", WHITE)


def rocketRender(b: Base; r: Rocket)
    let pos = base.zeroPos + r.pos
    circle(int(pos.x), int(pos.y), int(rocket.rad), BALL)
    fill_circle(int(pos.x) - 10, int(pos.y) - 10, int(rocket.rad / 4.0), BALL)

    let tailPos = calcPoint(pos, -45.0, r.rad)
    line(tailPos.x, tailPos.y, tailPos.x - 13.0, tailPos.y, BALL)
    line(tailPos.x - 13.0, tailPos.y, tailPos.x, tailPos.y + 13.0, BALL)
    line(tailPos.x, tailPos.y + 13.0, tailPos.x, tailPos.y, BALL)


def topLineRender(b: Base; r: Rocket)
    let statWidth: int = int(200.0 * r.baseFuel / r.maxBaseFuel)
    fill_rect(20, 27, statWidth, 15, BLUE)
    rect(20, 27, 200, 15, WHITE)
    set_font_size(16)
    text_out(20,  5, "GAS:", WHITE)

    let wCount: int = int(ceil(10.0 * r.addGravity / 250.0))
    for i in range(0, wCount)
        draw_image(weight_png, 70 + (i * 15), 7)


/* ---------------- UPDATE ---------------- */


def updateSpeed(var r: Rocket; dt: float)
    r.speed.y = clamp(r.speed.y + r.speedup - GRAVITY * dt, MIN_SPEED, MAX_SPEED)


def updateLandPos(var b: Base; r: Rocket; dt: float)
    if !base.hasFinished && base.hasStarted
        b.pos.x += 250.0 * dt
        b.hardLvl = min(int(b.pos.x) / 2500, 10)


def updatePos(var r: Rocket; b: Base; dt: float)
    r.pos.y = r.pos.y - r.speedup * 1500.0 * dt + GRAVITY * dt + r.addGravity * dt
    if r.pos.y <= 50.0 + r.rad - b.zeroPos.y
        r.speedup = 0.0
        r.speed.y = 0.0
        r.pos.y = 50.0 + r.rad - b.zeroPos.y
        r.addGravity += float(b.hardLvl) * 10.0
    elif r.pos.y > 0.0
        r.pos.y = 0.0
        base.hasFinished = true
        let rPos = b.zeroPos + r.pos
        eddExplosion(rPos, 40, BALL, b.hasFinished)


def rocketUpdate(var r: Rocket; b: Base; dt: float)
    if r.extraFuel > 0.0
        r.extraFuel -= 20.0 * dt
        addSpeedUp(r, 1.0 * dt, MAX_SPEEDUP / 3.0)
        addParticle(particles, r, 350.0, 2.0)
    elif r.baseFuel > 0.0 && b.button > 0.0
        r.baseFuel -= 3.0 * dt
        addSpeedUp(r, 0.3 * dt, MAX_SPEEDUP / 9.0)
        addParticle(particles, r, 250.0, 0.0)
    else
        addSpeedUp(r, -0.3 * dt, 0.0)

    if r.addGravity > 0.0
        r.addGravity = max(r.addGravity - 25.0 * dt, 0.0)

    updateSpeed(r, dt)
    updatePos(r, b, dt)


def particlesUpdate(var pList: array<Particle>; dt: float)
    if length(pList) > 0
        if (pList[0].life <= 0)
            erase(pList, 0)

    for p in pList
        p.pos.x -= p.moveX * dt
        p.rad += dt * 10.0
        p.dis += dt * p.spd
        p.life--


struct TouchData
    hasTouch: bool
    idx: int
    pos: float2
    color: uint


def npsUpdate(var npsList: array<Nps>; var r: Rocket; var b: Base; dt: float)
    var eraseIdx: int = -1
    var touchIdx: int = -1
    var touchData: TouchData
    for i in range(0, length(npsList))
        npsList[i].ang += 1.0 * dt
        npsList[i].realPos.x = npsList[i].pos.x
        npsList[i].realPos.y = npsList[i].pos.y + cos(npsList[i].ang) * npsList[i].moveY
        npsList[i].imgYpos = npsList[i].pos.y + cos(npsList[i].ang - 0.2) * npsList[i].moveY

        let n = npsList[i]
        if n.realPos.x + sw / 10.0 < b.pos.x
            eraseIdx = i

        let k1 = n.realPos.x - (b.pos.x + b.zeroPos.x)
        let k2 = n.realPos.y - r.pos.y
        let dist = sqrt(k1 * k1 + k2 * k2)
        if dist < r.rad + n.rad
            let cfg = npsCfgs[npsList[i].id]
            touchData.hasTouch = true
            touchData.idx = i
            touchData.pos.x = npsList[i].realPos.x - b.pos.x
            touchData.pos.y = b.zeroPos.y + npsList[i].realPos.y
            touchData.color = cfg.color

    if touchData.hasTouch
        let npsId: string = npsList[touchData.idx].id
        if npsId == "GAS"
            r.baseFuel = min(r.baseFuel + 10.0, r.maxBaseFuel)
        elif npsId == "BONUS"
            b.score += 10.0
        elif npsId == "THORN"
            b.hasFinished = true
            let rPos = b.zeroPos + r.pos
            eddExplosion(rPos, 40, BALL, b.hasFinished)
        elif npsId == "CLOUD"
            r.addGravity = 250.0

        eddExplosion(touchData.pos, 25, touchData.color, b.hasFinished)
        erase(npsList, touchData.idx)

    elif eraseIdx >= 0
        erase(npsList, eraseIdx)

    while length(npsList) < b.reqNps
        var newNps: Nps = addNps(npsList, b)
        push(npsList, newNps)


/* ---------------- ADD ---------------- */


var rInt: int4
def addParticle(var pList: array<Particle>; r: Rocket; spd, size: float)
    let tailPos = calcPoint(base.zeroPos + r.pos, -45.0, r.rad + 10.0)
    var p: Particle
    p.pos.x = tailPos.x
    p.pos.y = tailPos.y
    p.rad = 2.0 + size + random_float(rInt) * 3.0
    p.ang = -45.3 + random_float(rInt) * 0.6
    p.spd = spd + random_float(rInt) * 100.0
    p.life = 30 + int(random_float(rInt) * 10.0)
    p.color = BLUE
    push(pList, p)


def addParticle(var pList: array<Particle>; pos: float2; color: uint; moveX: float)
    var p: Particle
    p.pos.x = pos.x
    p.pos.y = pos.y
    p.rad = 1.0 + random_float(rInt) * 2.0
    p.ang = random_float(rInt) * 100.0
    p.spd = 3.0 + random_float(rInt) * 100.0
    p.life = 10 + int(random_float(rInt) * 5.0)
    p.moveX = moveX
    p.color = color
    push(pList, p)


def eddExplosion(pos: float2; pCount: int; color: uint; noMove: bool)
    let moveX: float = noMove ? 0.0 : 250.0
    for i in range(0, pCount)
        addParticle(explosions, pos, color, moveX)


def addSpeedUp(var r: Rocket; val, startVal: float)
    if val > 0.0 && r.speedup < startVal
        r.speedup = startVal
    r.speedup = max(min(r.speedup + val, MAX_SPEEDUP), 0.0)


def addNps(npsList: array<Nps>; b: Base) : Nps
    var prevX: float = sw / 2.0
    if length(npsList) > 0
        print("Add {length(npsList)}\n")
        prevX = npsList[length(npsList) - 1].pos.x

    let idx: int = int(random_float(rInt) * float(length(npsIds)))
    let id: string = npsIds[idx]
    let cfg: NpsCfg = npsCfgs[id]
    let rad = cfg.size.x + random_float(rInt) * cfg.size.y

    let dist = b.zeroPos.y - rad - sh / 5.0 - sh / 6.0

    let maxYmove: float = sh / 7.0
    var newNps: Nps
    newNps.id := id
    newNps.rad = rad
    newNps.pos.x = prevX + b.zeroPos.x / 1.5 + random_float(rInt) * (b.zeroPos.x / 2.0)
    newNps.pos.y = -sh / 6.0 - random_float(rInt) * dist
    newNps.moveY = b.hardLvl == 0 ? 0.0 : maxYmove / 3.0 + (maxYmove / 40.0 * float(b.hardLvl))
    newNps.ang = random_float(rInt) * 10.0

    return newNps


[export]
def initialize
    set_window_title("Denis Suslov")
    clear(npses)
    landReset(base)
    play_sound_loop(back_music, volume)
    rocketReset(rocket)
    return


[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    if get_key_up(VK_SPACE)
        if base.hasFinished
            clear(npses)
            landReset(base)
            rocketReset(rocket)

    npsUpdate(npses, rocket, base, dt)
    particlesUpdate(particles, dt)
    particlesUpdate(explosions, dt)
    if base.hasFinished
        return

    base.button -= dt * 10.0
    if get_mouse_button(MB_LEFT)
        base.hasStarted = true
        base.button = 1.0

    if !base.hasStarted
        return

    rocketUpdate(rocket, base, dt)
    updateLandPos(base, rocket, dt)
    return


[export]
def draw
    npsRender(npses, base)
    if !base.hasFinished
        rocketRender(base, rocket)
    particlesRender(particles)
    particlesRender(explosions)
    landRender(base, rocket)
    topLineRender(base, rocket)

    if base.hasFinished
        gameOverRender(base)

    if !base.hasStarted
        breafingRender(base)

    //if length(npses) > 0
    //    text_out(100,  5, "{npses[0].ang}", GREY)

    //text_out(600, 25, "{length(explosions)} / {length(particles)} / {length(npses)}", GREY)
    return
