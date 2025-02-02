Time formats
------------

Invalid time

  $ okra lint << EOF
  > # Title
  > 
  > - This is a KR (KR123)
  >   - @eng1 (1 day), eng2 (2 days)
  >   - My work
  > EOF
  File "<stdin>", line 4:
  Error: In objective "This is a KR (KR123)":
         Invalid time entry "@eng1 (1 day), eng2 (2 days)" found.
          Accepted formats are:
          - '@username (X days)' where X must be a multiple of 0.125
          - '@username (X hours)' where X must be a multiple of 1
          Multiple time entries must be comma-separated.
  [1]
  $ okra lint << EOF
  > # Title
  > 
  > - This is a KR (KR123)
  >   - @eng1 (1 day); @eng2 (2 days)
  >   - My work
  > EOF
  File "<stdin>", line 4:
  Error: In objective "This is a KR (KR123)":
         Invalid time entry "@eng1 (1 day); @eng2 (2 days)" found.
          Accepted formats are:
          - '@username (X days)' where X must be a multiple of 0.125
          - '@username (X hours)' where X must be a multiple of 1
          Multiple time entries must be comma-separated.
  [1]
  $ okra lint << EOF
  > # Title
  > 
  > - This is a KR (KR123)
  >   - @eng1 (1 day) @eng2 (2 days)
  >   - My work
  > EOF
  File "<stdin>", line 4:
  Error: In objective "This is a KR (KR123)":
         Invalid time entry "@eng1 (1 day) @eng2 (2 days)" found.
          Accepted formats are:
          - '@username (X days)' where X must be a multiple of 0.125
          - '@username (X hours)' where X must be a multiple of 1
          Multiple time entries must be comma-separated.
  [1]
  $ okra lint << EOF
  > # Title
  > 
  > - This is a KR (KR123)
  >   - @eng1 (. days)
  >   - My work
  > EOF
  File "<stdin>", line 4:
  Error: In objective "This is a KR (KR123)":
         Invalid time entry "@eng1 (. days)" found.
          Accepted formats are:
          - '@username (X days)' where X must be a multiple of 0.125
          - '@username (X hours)' where X must be a multiple of 1
          Multiple time entries must be comma-separated.
  [1]

  $ okra lint << EOF
  > # Title
  > 
  > - This is a KR (KR123)
  >   - @eng1 (. hours)
  >   - My work
  > EOF
  File "<stdin>", line 4:
  Error: In objective "This is a KR (KR123)":
         Invalid time entry "@eng1 (. hours)" found.
          Accepted formats are:
          - '@username (X days)' where X must be a multiple of 0.125
          - '@username (X hours)' where X must be a multiple of 1
          Multiple time entries must be comma-separated.
  [1]

Valid time

  $ okra lint << EOF
  > # Title
  > 
  > - This is a KR (KR123)
  >   - @eng1 (.5 hours)
  >   - My work
  > 
  > - This is a KR (KR124)
  >   - @eng1 (.5 days)
  >   - My work
  > 
  > - This is a KR (KR124)
  >   - @eng1 (0.5 days)
  >   - My work
  > 
  > - This is a KR (KR124)
  >   - @eng1 (0.5 day)
  >   - My work
  > 
  > - This is a KR (KR124)
  >   - @eng1 (1.5 days), @eng1 (.5 hours)
  >   - My work
  > EOF
  File "<stdin>", line 4:
  Error: In objective "This is a KR (KR123)":
         Invalid time entry "@eng1 (.5 hours)" found.
          Accepted formats are:
          - '@username (X days)' where X must be a multiple of 0.125
          - '@username (X hours)' where X must be a multiple of 1
          Multiple time entries must be comma-separated.
  File "<stdin>", line 20:
  Error: In objective "This is a KR (KR124)":
         Invalid time entry "@eng1 (1.5 days), @eng1 (.5 hours)" found.
          Accepted formats are:
          - '@username (X days)' where X must be a multiple of 0.125
          - '@username (X hours)' where X must be a multiple of 1
          Multiple time entries must be comma-separated.
  [1]

Using the configuration file to change the default number of working days.

  $ cat > valid-conf.yaml << EOF
  > work_days_in_a_week: 1.5
  > EOF
  $ okra lint --engineer --conf valid-conf.yaml << EOF
  > # Last week
  > 
  > - This is a KR (KR1)
  >   - @eng1 (1.5 days)
  >   - My work
  > EOF
  [OK]: <stdin>
  $ okra lint --engineer --conf valid-conf.yaml << EOF
  > # Last week
  > 
  > - This is a KR (KR1)
  >   - @eng1 (0.5 days)
  >   - My work
  > EOF
  File "<stdin>", line 1:
  Error: Invalid total time found for eng1:
         Reported 0.5 days, expected 1.5 days.
  [1]

Using 0.125 days granularity:

  $ okra lint << EOF
  > # Title
  > 
  > - This is a KR (KR123)
  >   - @eng1 (.125 day)
  >   - My work
  > 
  > - This is a KR (KR124)
  >   - @eng1 (.25 days)
  >   - My work
  > 
  > - This is a KR (KR124)
  >   - @eng1 (4.625 days)
  >   - My work
  > EOF
  [OK]: <stdin>

Invalid granularity:

  $ okra lint << EOF
  > # Title
  > 
  > - This is a KR (KR123)
  >   - @eng1 (.12 day)
  >   - My work
  > EOF
  File "<stdin>", line 4:
  Error: In objective "This is a KR (KR123)":
         Invalid time entry "@eng1 (.12 day)" found.
          Accepted formats are:
          - '@username (X days)' where X must be a multiple of 0.125
          - '@username (X hours)' where X must be a multiple of 1
          Multiple time entries must be comma-separated.
  [1]
