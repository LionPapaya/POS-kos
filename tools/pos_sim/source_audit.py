"""Fast static checks for the KerboScript tree before KSP is opened."""

from dataclasses import dataclass
import re
from pathlib import Path


RUN_PATH = re.compile(r"\b(?:runpath|runoncepath)\s*\(\s*\"([^\"]+)\"", re.IGNORECASE)
FUNCTION_NAME = re.compile(r"\bfunction\s+([a-z_][a-z0-9_]*)\s*\{", re.IGNORECASE)
DEFINED_NAME = re.compile(r"\bdefined\s*(?:\(\s*)?([a-z_][a-z0-9_]*)\b", re.IGNORECASE)

# kOS CLOBBERBUILTINS identifiers, checked against KSP-KOS/KOS develop at
# 8f281a459b6ea0ba917c91bbbc117e68bb948199 (2026-05-14). Function names come
# from [Function]/[FunctionAttribute] registrations in src/kOS and src/kOS.Safe,
# plus RUNPATH/RUNONCEPATH from the parser and commands/runprogram.rst. Bound
# names come from src/kOS/Binding registrations and VesselTarget's shortcut
# suffix table; system locks come from kOS.Safe/Compilation/KS/UserFunction.cs.
# The upstream source is https://github.com/KSP-KOS/KOS/tree/8f281a459b6ea0ba917c91bbbc117e68bb948199
# and the user-facing rule is documented at
# https://ksp-kos.github.io/KOS_DOC/language/variables.html#clobbering-built-in-names .
# Celestial body names are installed dynamically from the active KSP game and
# cannot be exhaustively listed here.
BUILTIN_FUNCTIONS = frozenset("""
    ABS ADD ADDALARM ALLWAYPOINTS ANGLEAXIS ANGLEDIFF ARCCOS ARCSIN ARCTAN
    ARCTAN2 BODY BODYATMOSPHERE BODYEXISTS BOUNDS BUILDLIST CAREER CD CEILING
    CHAR CHDIR CLEARGUIS CLEARSCREEN CLEARVECDRAWS CONSTANT COPY_DEPRECATED
    COPYPATH COS CREATE CREATEDIR CREATEORBIT DEBUGDUMP DEBUGFREEZEGAME
    DELETE_DEPRECATED DELETEALARM DELETEPATH DROPPRIORITY EDIT EXISTS FLOOR
    GETVOICE GUI HEADING HIGHLIGHT HSV HSVA HUDTEXT LATLNG LEX LEXICON LIST
    LISTALARMS LN LOAD LOG10 LOGFILE LOOKDIRUP MAKEBUILTINDELEGATE MAX MIN MOD
    MOVEPATH NODE NOTE OPEN ORBITAT PATH PIDLOOP POSITIONAT PRINT PRINTAT
    PRINTLIST PROCESSOR PROFILERESULT Q QUEUE R RANDOM RANDOMSEED RANGE READJSON
    REBOOT REMOVE RENAME_FILE_DEPRECATED RENAME_VOLUME_DEPRECATED RGB RGBA
    ROTATEFROMTO ROUND RUN RUNONCEPATH RUNPATH SCRIPTPATH SELECTAUTOPILOTMODE
    SHUTDOWN SIN SLIDENOTE SQRT STACK STAGE STOPALLVOICES SWITCH TAN TIME
    TIMESPAN TIMESTAMP TOGGLEFLYBYWIRE TRANSFER TRANSFERALL UNCHAR UNIQUESET V
    VANG VCRS VDOT VECDRAW VECDRAWARGS VECTORANGLE VECTORCROSSPRODUCT
    VECTORDOTPRODUCT VECTOREXCLUDE VELOCITYAT VESSEL VOLUME VXCL WARPTO
    WAYPOINT WRITEJSON
""".split())

# Static, unqualified bound variables exposed by kOS. AG1-AG10 are core action
# groups and AG11-AG250 are registered by the official ActionGroupsExtended
# integration when that add-on is installed.
BUILTIN_BOUND_VARIABLES = frozenset("""
    ABORT ACTIVESHIP ADDONS AG1 AG2 AG3 AG4 AG5 AG6 AG7 AG8 AG9 AG10
    AIRSPEED ALLNODES ALT ALTITUDE ANGULARMOMENTUM ANGULARVEL ANGULARVELOCITY
    APOAPSIS ARCHIVE AVAILABLETHRUST BAYS BLACK BLUE BODY BRAKES CHUTES CHUTESSAFE
    CONFIG CONSTANT CONTROLCONNECTION CORE CYAN DEPLOYDRILLS DONOTHING DRILLS
    ENCOUNTER ETA FACING FUELCELLS GEAR GEOPOSITION GREEN GREY GROUNDSPEED
    HASTARGET HASNODE HEADING HOMECONNECTION INTAKES ISRU KUNIVERSE LADDERS
    LATITUDE LEGS LIGHTS LONGITUDE MAGENTA MAPVIEW MASS MAXTHRUST MISSIONTIME
    NAVMODE NEXTNODE NORTH OBT OPCODESLEFT ORBIT PANELS PERIAPSIS PROGRADE
    RADIATORS RCS RED RETROGRADE SAS SASMODE SENSOR SESSIONTIME SHIP SHIPNAME
    SOLARPRIMEVECTOR SRFPROGRADE SRFRETROGRADE STAGE STATUS STEERING
    STEERINGMANAGER SURFACESPEED TARGET TERMINAL THROTTLE TIME UP VELOCITY
    VERSION VERTICALSPEED WARP WARPMODE WHEELSTEERING
    WHEELSTEERINGPID WHEELTHROTTLE WHITE YELLOW GRAY PURPLE
""".split()) | frozenset(f"AG{index}" for index in range(11, 251))

# These bound variables have setters. A direct SET to them is a valid kOS
# operation, but declarations and function names can still hide the binding.
BUILTIN_SETTABLE_VARIABLES = frozenset("""
    ABORT AG1 AG2 AG3 AG4 AG5 AG6 AG7 AG8 AG9 AG10 BAYS BRAKES CHUTES CHUTESSAFE
    DEPLOYDRILLS DRILLS FUELCELLS GEAR INTAKES ISRU LADDERS LEGS LIGHTS MAPVIEW
    NAVMODE PANELS RADIATORS RCS SAS SASMODE SHIPNAME TARGET WARP WARPMODE
    WHEELSTEERINGPID
""".split()) | frozenset(f"AG{index}" for index in range(11, 251))

SYSTEM_LOCKS = frozenset("THROTTLE STEERING WHEELTHROTTLE WHEELSTEERING".split())
READ_ONLY_BUILTINS = BUILTIN_BOUND_VARIABLES - BUILTIN_SETTABLE_VARIABLES - SYSTEM_LOCKS
READ_ONLY_SHIP_SUFFIXES = frozenset("""
    HEADING PROGRADE RETROGRADE FACING MAXTHRUST AVAILABLETHRUST VELOCITY
    GEOPOSITION LATITUDE LONGITUDE UP NORTH BODY ANGULARMOMENTUM ANGULARVEL
    ANGULARVELOCITY MASS VERTICALSPEED GROUNDSPEED SURFACESPEED AIRSPEED
    ALTITUDE APOAPSIS PERIAPSIS SENSOR SENSORS SRFPROGRADE SRFRETROGRADE OBT
    STATUS NAME
""".split())

IDENTIFIER = re.compile(r"[a-z_][a-z0-9_]*", re.IGNORECASE)
FUNCTION_DECLARATION = re.compile(r"\bfunction\s+([a-z_][a-z0-9_]*)\s*\{", re.IGNORECASE)
DECLARATION_START = re.compile(
    r"\b(?:declare\s+(?:(?:local|global)\s+)?|local\s+|global\s+)",
    re.IGNORECASE,
)
PARAMETER_START = re.compile(r"\bparameter\b", re.IGNORECASE)
FOR_DECLARATION = re.compile(r"\bfor\s+([a-z_][a-z0-9_]*)\s+in\b", re.IGNORECASE)
ASSIGNMENT_START = re.compile(r"\b(set|lock)\b", re.IGNORECASE)
SHIP_SUFFIX_WRITE = re.compile(
    r"\b(?:set|lock)\s+ship\s*:\s*([a-z_][a-z0-9_]*)\s+to\b",
    re.IGNORECASE,
)


def _statement_end(source, start):
    """Return the first top-level KerboScript period after start."""
    depth = 0
    for index in range(start, len(source)):
        char = source[index]
        if char in "([{":
            depth += 1
        elif char in ")]}" and depth:
            depth -= 1
        elif char in ")]}" and not depth:
            continue
        elif char == "." and depth == 0:
            before = source[index - 1] if index else " "
            after = source[index + 1] if index + 1 < len(source) else " "
            if not (before.isdigit() and after.isdigit()):
                return index
    return len(source)


def _split_top_level(source, separator=","):
    parts = []
    depth = 0
    start = 0
    for index, char in enumerate(source):
        if char in "([{":
            depth += 1
        elif char in ")]}" and depth:
            depth -= 1
        elif char == separator and depth == 0:
            parts.append(source[start:index])
            start = index + 1
    parts.append(source[start:])
    return parts


def _binding_declarations(code):
    """Yield each unqualified identifier created by a declaration or write."""
    bindings = {}

    def add(name, offset, kind):
        bindings[(offset, name.lower())] = (name, offset, kind)

    for match in FUNCTION_DECLARATION.finditer(code):
        add(match.group(1), match.start(1), "function")

    for match in PARAMETER_START.finditer(code):
        start = match.end()
        end = _statement_end(code, start)
        for part in _split_top_level(code[start:end]):
            name = IDENTIFIER.match(part.lstrip())
            if name:
                offset = start + len(part) - len(part.lstrip())
                add(name.group(0), offset, "parameter")

    for match in FOR_DECLARATION.finditer(code):
        add(match.group(1), match.start(1), "for")

    for match in DECLARATION_START.finditer(code):
        start = match.end()
        end = _statement_end(code, start)
        first = IDENTIFIER.match(code[start:end].lstrip())
        if not first or first.group(0).lower() in {"function", "parameter", "lock"}:
            continue
        for part in _split_top_level(code[start:end]):
            leading = part.lstrip()
            name = IDENTIFIER.match(leading)
            if not name or not re.match(r"\s+(?:to|is)\b", leading[name.end():], re.IGNORECASE):
                continue
            offset = start + len(part) - len(leading)
            add(name.group(0), offset, "declaration")

    for match in ASSIGNMENT_START.finditer(code):
        kind = match.group(1).lower()
        start = match.end()
        end = _statement_end(code, start)
        for part in _split_top_level(code[start:end]):
            leading = part.lstrip()
            name = IDENTIFIER.match(leading)
            if not name or not re.match(r"\s+to\b", leading[name.end():], re.IGNORECASE):
                continue
            offset = start + len(part) - len(leading)
            add(name.group(0), offset, kind)

    return sorted(bindings.values(), key=lambda item: item[1])


@dataclass(frozen=True)
class Finding:
    severity: str
    path: Path
    line: int
    message: str


def _without_comments(source):
    output = []
    in_string = False
    escaped = False
    index = 0
    while index < len(source):
        char = source[index]
        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            output.append(char)
            index += 1
            continue
        if char == "/" and index + 1 < len(source) and source[index + 1] == "/":
            while index < len(source) and source[index] != "\n":
                output.append(" ")
                index += 1
            continue
        output.append(char)
        index += 1
    return "".join(output)


def _without_strings(source):
    """Mask quoted text while retaining newlines and source offsets."""
    output = list(source)
    in_string = False
    escaped = False
    for index, char in enumerate(source):
        if in_string:
            if char != "\n":
                output[index] = " "
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            output[index] = " "
            in_string = True
    return "".join(output)


def _resolve_volume_zero(script_root, value):
    value = value.replace("\\", "/")
    if value.lower().startswith("0:/"):
        relative = value[3:]
    elif value.startswith("/"):
        relative = value[1:]
    else:
        return None
    candidate = script_root / relative
    if not candidate.suffix:
        candidate = candidate.with_suffix(".ks")
    if candidate.exists():
        return candidate
    # kOS source frequently runs on case-insensitive installations. Return a
    # case-insensitive match but let the caller warn about portability.
    current = script_root
    for part in Path(relative).with_suffix(".ks").parts:
        matches = [child for child in current.iterdir() if child.name.lower() == part.lower()] if current.exists() else []
        if not matches:
            return candidate
        current = matches[0]
    return current


def audit_file(path, script_root, function_names=None):
    path = Path(path)
    findings = []
    try:
        source = path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError as exc:
        return [Finding("error", path, exc.start, "source is not valid UTF-8")]
    clean = _without_comments(source)
    code = _without_strings(clean)
    if function_names is None:
        function_names = {match.group(1).lower() for match in FUNCTION_NAME.finditer(code)}
    # A bare function name can auto-invoke in kOS. DEFINED is a variable
    # existence check, not a safe callable-presence check; the hosted runtime
    # previously accepted this and missed missing-argument failures in KSP.
    for match in DEFINED_NAME.finditer(code):
        name = match.group(1)
        if name.lower() in function_names:
            findings.append(Finding(
                "error", path, code.count("\n", 0, match.start()) + 1,
                f"DEFINED targets function '{name}'; call it explicitly or check a readiness variable",
            ))
    stack = []
    pairs = {"}": "{", ")": "(", "]": "["}
    in_string = False
    escaped = False
    for index, char in enumerate(clean):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char in "{([":
            stack.append((char, index))
        elif char in "})]":
            if not stack or stack[-1][0] != pairs[char]:
                findings.append(Finding("error", path, clean.count("\n", 0, index) + 1, f"unmatched {char}"))
            else:
                stack.pop()
    if in_string:
        findings.append(Finding("error", path, clean.count("\n") + 1, "unterminated string"))
    for char, index in stack:
        findings.append(Finding("error", path, clean.count("\n", 0, index) + 1, f"unclosed {char}"))

    for match in RUN_PATH.finditer(clean):
        resolved = _resolve_volume_zero(script_root, match.group(1))
        if resolved is None:
            continue
        line = clean.count("\n", 0, match.start()) + 1
        if not resolved.exists():
            findings.append(Finding("warning", path, line, f"static RUNPATH target does not exist: {match.group(1)}"))
        else:
            requested = Path(match.group(1)).name
            if requested and requested.lower() == resolved.name.lower() and requested != resolved.name:
                findings.append(Finding("warning", path, line, f"RUNPATH case differs from disk: {match.group(1)}"))

    for name, offset, binding_kind in _binding_declarations(code):
        upper = name.upper()
        if upper not in BUILTIN_FUNCTIONS | BUILTIN_BOUND_VARIABLES | SYSTEM_LOCKS:
            continue
        # SET is how supported settable bound values are used, and LOCK is how
        # the four system control locks are created. Those forms are legal.
        if binding_kind == "set" and upper in BUILTIN_SETTABLE_VARIABLES:
            continue
        if binding_kind == "lock" and upper in SYSTEM_LOCKS:
            continue

        line = code.count("\n", 0, offset) + 1
        if upper in BUILTIN_FUNCTIONS:
            message = f"variable name '{name}' clobbers kOS built-in function '{upper}'"
        elif upper in SYSTEM_LOCKS:
            message = f"variable name '{name}' clobbers kOS system lock '{upper}'"
        elif upper in READ_ONLY_BUILTINS:
            message = f"variable name '{name}' clobbers read-only kOS built-in '{upper}'"
        else:
            message = f"variable name '{name}' clobbers kOS built-in variable '{upper}'"
        findings.append(Finding("error", path, line, message))
    for match in SHIP_SUFFIX_WRITE.finditer(code):
        suffix = match.group(1).upper()
        if suffix in READ_ONLY_SHIP_SUFFIXES:
            line = code.count("\n", 0, match.start()) + 1
            findings.append(Finding(
                "error", path, line,
                f"cannot write read-only kOS suffix 'SHIP:{suffix}'",
            ))
    return findings


def audit_tree(repository_root):
    repository_root = Path(repository_root)
    script_root = repository_root / "Script"
    findings = []
    paths = sorted(script_root.rglob("*.ks"))
    function_names = set()
    for path in paths:
        try:
            code = _without_strings(_without_comments(path.read_text(encoding="utf-8-sig")))
        except UnicodeDecodeError:
            continue  # audit_file supplies the source diagnostic below.
        function_names.update(match.group(1).lower() for match in FUNCTION_NAME.finditer(code))
    for path in paths:
        findings.extend(audit_file(path, script_root, function_names))
    return paths, findings
