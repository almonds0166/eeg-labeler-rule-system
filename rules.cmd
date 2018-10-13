@py -3.6 -x %0 %* & @pause & @goto :eof

'''
Contact Kotocade for help.
Written in Python 3.6
'''

import sys, datetime

assert len(sys.argv[1:]), 'Drag your file of sleep stages onto the `.cmd` file.'

'''
Constants
'''

PLOT = False

AWAKE   = 'Awake'
SWS     = 'Deep'
REM     = 'Rem'
LIGHT   = 'Light'

DISCARD = None

HEADER  = 'User,Schedule,Date,Day,Adapted,EEG,Core number,Beginning time,'
HEADER += 'Wake,NREM1-2,SWS-1,Nrem2-1.1,Rem-1,Nrem2-1.2,SWS-2,Nrem2-2.1,Rem-2,Nrem2-2.2,SWS-3,Nrem2-3.1,Rem-3,Nrem2-3.2,SWS-4,Nrem2-4.1,Rem-4,Nrem2-4.2,SWS-5,Nrem2-5.1,Rem-5,Nrem2-5.2,Light diff,SWS diff,REM diff,Total diff'
COMMAS  = HEADER.count(',') - 3

'''
Some functions
'''

if PLOT:
   try:
      import matplotlib.pyplot as plt
      def plot_sleep(ell, title=''):
         if ell[0] == 'Discard': return
         heights = { AWAKE: 3, REM: 2, LIGHT: 1, SWS: 0 }
         x, y = [], []
         d = 0
         for stage, duration in ell:
            x += [d, d + duration]
            y += 2 * [heights[stage]]
            d += duration
         plt.title(title)
         plt.plot(x, y, color='blue', linewidth=3)
         plt.xlabel('Minutes')
         plt.yticks(range(4), ('SWS', 'Light', 'REM', 'Awake'))
         plt.hlines(range(4), x[0], x[-1], colors='gray', linestyles='dotted')
         plt.show()
      PLOT = True
   except:
      PLOT = False

def pipe(raw):
   ell = []
   last_item = '^'
   for item in raw.split(' '):
      if last_item == item:
         ell[-1][1] = ell[-1][1] + 5
      else:
         ell.append([item, 5])
         last_item = item
   return ell

def unpipe(cooked):
   if cooked[0] == 'Discard': return cooked[0]
   ell = []
   for stage, duration in cooked:
      ell += [stage] * duration
   return ' '.join(ell)

# Measure the percent differences between two lists of sleep stage blocks
# Takes in UNPIPED data
def percent_difference(before, after):
   before = before.split(' ')
   after  = after.split(' ')
   count  = 0
   l = min(len(before), len(after))
   for i in range(l):
      count += int(before[i] != after[i])
   return str(int(100 * count / l)) + '%'

# Takes in PIPED data
def total_stage(ell, sleep_stage):
   total_time = 0
   for stage, duration in ell:
      if stage == sleep_stage:
         total_time += duration
   return total_time

def stage_diff(before, after, sleep_stage):
   a = total_stage( after, sleep_stage)
   b = total_stage(before, sleep_stage)
   return str(int(100 * (a - b) / b)) + '%'

'''
Final criteria
'''

always = lambda bindings: True

def gt(m, n):
   def check(bindings):
      left  = bindings.get(m, m)
      right = bindings.get(n, n)
      return left > right
   return check

def lteq(m, n):
   def check(bindings):
      left  = bindings.get(m, m)
      right = bindings.get(n, n)
      return left <= right
   return check

def at_the_start(bindings):
   return not bindings['index']

def at_the_end(bindings):
   return bindings['index'] == bindings['end']

def not_at_start(bindings):
   return bindings['index']

def not_at_end(bindings):
   return bindings['index'] != bindings['end']

'''
Rule abstraction
'''

class Rule:
   def __init__(self, before, after, *criteria):
      self.before   = before
      self.after    = after
      self.criteria = criteria
   def __radd__(self, ell):
      return ell + [self]
   def __repr__(self):
      return '(' + str(self.before) + ' --> ' + str(self.after) + ')'
   def __len__(self):
      return len(self.before)
   def match(self, index, ell):
      if len(self) != len(ell): return {}
      bindings = {}
      for i in range(len(ell)):
         #print(bindings)
         if ell[i][0] != self.before[i][0]: return {}
         if type(ell[i][0]) == int:
            if ell[i][0] != self.before[i][1]: return {}
         else:
            bindings[self.before[i][1]] = ell[i][1]
      temp = bindings.copy()
      for V, v in temp.items():
         for W, w in temp.items():
            bindings[V + W] = v + w
      bindings['index'] = index
      bindings['end'] = len(ell) - 1
      for criterion in self.criteria:
         if not criterion(bindings):
            return {}
      return bindings
   def fire(self, bindings):
      if self.after == DISCARD:
         return DISCARD
      ell = []
      for stage, key in self.after:
         ell.append([stage, bindings.get(key, key)])
      return ell

'''
All the rules
'''

RULES = []

# Combine adjacent stages
RULES += Rule([[AWAKE, 'a'], [AWAKE, 'b']], [[AWAKE, 'a' + 'b']])
RULES += Rule([[LIGHT, 'a'], [LIGHT, 'b']], [[LIGHT, 'a' + 'b']])
RULES += Rule([[  REM, 'a'], [  REM, 'b']], [[  REM, 'a' + 'b']])
RULES += Rule([[  SWS, 'a'], [  SWS, 'b']], [[  SWS, 'a' + 'b']])

# Discard anything with an interruption strictly longer than 15 minutes.
RULES += Rule([[AWAKE, 'a']], DISCARD, gt('a', 15), not_at_start, not_at_end)

# If Light in middle of REM or SWS
# then move to closest edge
RULES += Rule([[REM, 'a'], [LIGHT, 'b'], [REM, 'c']], [[REM, 'a' + 'c'], [LIGHT, 'b']],   gt('a', 'b'))
RULES += Rule([[REM, 'a'], [LIGHT, 'b'], [REM, 'c']], [[LIGHT, 'b'], [REM, 'a' + 'c']], lteq('a', 'b'))
RULES += Rule([[SWS, 'a'], [LIGHT, 'b'], [SWS, 'c']], [[SWS, 'a' + 'c'], [LIGHT, 'b']],   gt('a', 'b'))
RULES += Rule([[SWS, 'a'], [LIGHT, 'b'], [SWS, 'c']], [[LIGHT, 'b'], [SWS, 'a' + 'c']], lteq('a', 'b'))

# REM or SWS in the middle of SWS or REM
RULES += Rule([[REM, 'a'], [SWS, 'b'], [REM, 'c']], [[REM, 'a' + 'c'], [REM, 'b']], lteq('b', 15))
RULES += Rule([[SWS, 'a'], [REM, 'b'], [SWS, 'c']], [[SWS, 'a' + 'c'], [SWS, 'b']], lteq('b', 15))

# REM at start is actually LIGHT
# And SWS at the start is actually WAKE
RULES += Rule([              [REM, 'a']], [              [LIGHT, 'a']], at_the_start)
RULES += Rule([[AWAKE, 'a'], [REM, 'b']], [[AWAKE, 'a'], [LIGHT, 'b']], at_the_start)

RULES += Rule([              [SWS, 'a']], [[AWAKE,       'a']], at_the_start)
RULES += Rule([[AWAKE, 'a'], [SWS, 'b']], [[AWAKE, 'a' + 'b']], at_the_start)

# Wakes inbetween REM or SWS
RULES += Rule([[REM, 'a'], [AWAKE, 'b'], [REM, 'c']], [[REM, 'a' + 'b'], [REM, 'c']], lteq('b', 15))
RULES += Rule([[SWS, 'a'], [AWAKE, 'b'], [SWS, 'c']], [[SWS, 'a' + 'b'], [SWS, 'c']], lteq('b', 15))

'''
Even more functions
'''

# Run one rule at a time
# Returns updated list if a rule fired, False if no rule fired.
def forward(ell):
   for r in range(len(RULES)):
      rule = RULES[r]
      j = len(rule)
      for i in range(len(ell)):
         # Skip if this rule is too long to apply toward the end of the list
         if i + j > len(ell): break
         bindings = rule.match(i, ell[i : i + j])
         if not bindings: continue
         temp = rule.fire(bindings)
         if not temp:
            return DISCARD
         ell[i : i + j] = temp
         return ell
   return False

# Input is first two blocks, which is theoretically AWAKE and LIGHT
# Get WAKE and NREM1-2 time, final time for next cycle
def parse_left(ell):
   left, right = ell[0:2]
   if left[0] == AWAKE:
      return str(left[1]) + ',' + str(left[1] + right[1]), left[1] + right[1], ell[2:]
   return '0,' + str(left[1]), left[1], ell[1:] # else

# Takes in right half
# Returns dictionary of {SWS, 'N.1', REM, 'N.2'}, end time,  remaining right half
def parse_right(en, time):
   start = time
   def blanks(ans):
      ans[  SWS] = str(ans.get(  SWS,      start))
      ans['N.1'] = str(ans.get('N.1', ans[  SWS]))
      ans[  REM] = str(ans.get(  REM, ans['N.1']))
      ans['N.2'] = str(ans.get('N.2', ans[  REM]))
      return ans
   ans = {}
   for i in range(len(en)):
      stage, duration = en[i]
      if not ans:
         time += duration
         if stage == SWS:
            ans[SWS] = time
         elif stage == LIGHT:
            ans['N.1'] = time
         else: # REM
            ans[REM] = time
         continue
      if not 'N.1' in ans and not REM in ans and not 'N.2' in ans:
         if stage == SWS:
            return blanks(ans), time, en[i + 1 :]
         time += duration
         if stage == LIGHT:
            ans['N.1'] = time
         else: # REM
            ans[REM] = time
         continue
      if not REM in ans and not 'N.2' in ans:
         if stage == SWS:
            return blanks(ans), time, en[i + 1 :]
         time += duration
         if stage == LIGHT:
            ans['N.2'] = time
         else: # REM
            ans[REM] = time
         continue
      if not 'N.2' in ans:
         if stage == SWS or stage == REM:
            return blanks(ans), time, en[i + 1 :]
         time += duration
         ans['N.2'] = time
         continue
      return blanks(ans), time, en[i + 1 :]
   return blanks(ans), time, []

def csvize(ell):
   if ell == ['Discard']: return 'Discard'
   s, time, en = parse_left(ell)
   while en:
      ans, time, en = parse_right(en, time)
      s += ',' + ans[SWS] + ',' + ans['N.1'] + ',' + ans[REM] + ',' + ans['N.2']
   return s

filename = sys.argv[1]
outfile = 'output_' + \
   datetime.datetime.utcnow().strftime('%Y-%m-%d_%H-%M-%S') + \
   '.csv'

extra = []
ells = []
with open(filename, 'r') as inp:
   lines = inp.read().splitlines()
   for line in lines:
      temp = line.split(',')
      extra.append(','.join(temp[:-1]))
      ells.append(pipe(temp[-1].rstrip(' ')))

lines = []
for ell in ells:
   before = ell.copy()
   if PLOT: plot_sleep(ell, 'Before')
   count = 0
   while True:
      temp = forward(ell)
      if temp == DISCARD: ell = ['Discard']
      if not temp: break
      ell = temp
      count += 1
   if ell == ['Discard']: continue # Don't even bother putting it in the CSV
   temp = extra[0] + ',,' + csvize(ell)
   light_diff = stage_diff(before, ell, LIGHT)
   sws_diff   = stage_diff(before, ell,   SWS)
   rem_diff   = stage_diff(before, ell,   REM)
   total_diff = percent_difference(unpipe(before), unpipe(ell))
   lines.append(temp + ',' * (COMMAS - temp.count(',')) + light_diff + ',' + sws_diff + ',' + rem_diff + ',' + total_diff)
   del extra[0]
   print(count, 'rules fired.')
   if PLOT: plot_sleep(ell, 'After')

with open(outfile, 'w') as out:
   out.write(HEADER + '\n')
   out.write('\n'.join(lines))
