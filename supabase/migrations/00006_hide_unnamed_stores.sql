-- 상호 미등록('업소명없음')·숫자뿐인 이름·한 글자 이름 숨김
UPDATE public.places
   SET is_active = FALSE
 WHERE source = 'SEMAS'
   AND (name ~ '(없음|미상)' OR name ~ '^[0-9 \-]+$' OR char_length(btrim(name)) < 2);
