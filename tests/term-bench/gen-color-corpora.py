import os, sys
base = sys.argv[1]
DENS = [0, 4, 8, 16, 24, 32, 48, 64]; NL = 40000; VIS = 60
FILLER = "the quick brown fox jumps over the lazy dog 0123456789 abcdefghijklmnopqrstuvwxyz"
# The SAME twelve colours in three encodings. Only the encoding varies:
#   pal  \e[31m        short  form, WezTerm stores inline (SmallColor::PaletteIndex)
#   idx  \e[38;5;1m    long   form, WezTerm stores inline  (still a palette index)
#   true \e[38;2;r;g;bm long  form, WezTerm CANNOT store inline -> Box<FatAttributes>
# idx-vs-true is the heap-spill test; pal-vs-idx is the encoding-length control.
PAL = [31,32,33,34,35,36,91,92,93,94,95,96]
IDX = [1,2,3,4,5,6,9,10,11,12,13,14]
RGB = [(205,0,0),(0,205,0),(205,205,0),(0,0,238),(205,0,205),(0,205,205),
       (255,0,0),(0,255,0),(255,255,0),(92,92,255),(255,0,255),(0,255,255)]
def seq(mode, k):
    if mode == "pal":  return "\033[%dm" % PAL[k % 12]
    if mode == "idx":  return "\033[38;5;%dm" % IDX[k % 12]
    r,g,b = RGB[k % 12]; return "\033[38;2;%d;%d;%dm" % (r,g,b)
for mode in ("pal","idx","true"):
    d_dir = os.path.join(base, mode); os.makedirs(d_dir, exist_ok=True)
    for d in DENS:
        path = os.path.join(d_dir, "sgr-d%d.txt" % d)
        if os.path.exists(path): continue
        with open(path, "w") as f:
            for i in range(NL):
                text = (FILLER[i % len(FILLER):] + FILLER)[:VIS]
                if d == 0:
                    f.write(text + "\n"); continue
                per = max(1, VIS // d); parts = []; used = 0
                for k in range(d):
                    parts.append(seq(mode, i + k))
                    chunk = text[used:used + per]; used += len(chunk)
                    parts.append(chunk)
                if used < VIS: parts.append(text[used:VIS])
                parts.append("\033[0m\n")
                f.write("".join(parts))
